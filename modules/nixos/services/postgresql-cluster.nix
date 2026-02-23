{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "postgresql-cluster"
  ];
  description = "PostgreSQL primary/replica cluster";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the PostgreSQL cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "data";
        description = "Topology network name for data traffic.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "Port for the PostgreSQL server.";
      };
      replicationUser = lib.mkOption {
        type = lib.types.str;
        default = "replicator";
        description = "Username for streaming replication.";
      };
      superuserPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the superuser password.";
      };
      replicationPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the replication user password.";
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      ...
    }:
    let
      topo = config.psyclyx.topology;
      topoLib = topo.enriched;
      hostname = config.psyclyx.nixos.host;
      labIdx = topo.hosts.${hostname}.labIndex;

      dataNet = topoLib.networks.${cfg.dataNetwork};
      bindAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

      labIndices = map (name: topo.hosts.${name}.labIndex) cfg.clusterNodes;
      sortedIndices = builtins.sort builtins.lessThan labIndices;
      primaryIdx = builtins.head sortedIndices;

      isPrimary = labIdx == primaryIdx;

      primaryAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + primaryIdx)}";

      allAddrs = map (
        name:
        let
          idx = topo.hosts.${name}.labIndex;
        in
        "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + idx)}"
      ) cfg.clusterNodes;

      hbaEntries = lib.concatMapStringsSep "\n" (addr: ''
        host replication ${cfg.replicationUser} ${addr}/32 md5
        host all all ${addr}/32 md5
      '') allAddrs;

      pgDataDir = "/var/lib/postgresql/16";
    in
    {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
        enableTCPIP = true;
        settings = lib.mkMerge [
          {
            port = cfg.port;
            listen_addresses = lib.mkForce "${bindAddr},localhost";
            max_connections = 200;
          }
          (lib.mkIf isPrimary {
            wal_level = "replica";
            max_wal_senders = 10;
            hot_standby = true;
          })
          (lib.mkIf (!isPrimary) {
            hot_standby = true;
          })
        ];
        authentication = lib.mkAfter ''
          ${hbaEntries}
        '';
      };

      systemd.services.postgresql-primary-init = lib.mkIf isPrimary {
        description = "Initialize PostgreSQL primary: create replication user and set superuser password";
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          Group = "postgres";
        };
        script = ''
          ${lib.optionalString (cfg.replicationPasswordFile != null) ''
            REP_PASS=$(cat ${cfg.replicationPasswordFile})
            ${pkgs.postgresql_16}/bin/psql -p ${toString cfg.port} -tc \
              "SELECT 1 FROM pg_roles WHERE rolname='${cfg.replicationUser}'" | \
              ${pkgs.gnugrep}/bin/grep -q 1 || \
              ${pkgs.postgresql_16}/bin/psql -p ${toString cfg.port} -c \
                "CREATE ROLE ${cfg.replicationUser} WITH REPLICATION LOGIN PASSWORD '$REP_PASS';"
            ${pkgs.postgresql_16}/bin/psql -p ${toString cfg.port} -c \
              "ALTER ROLE ${cfg.replicationUser} WITH PASSWORD '$REP_PASS';"
          ''}
          ${lib.optionalString (cfg.superuserPasswordFile != null) ''
            SU_PASS=$(cat ${cfg.superuserPasswordFile})
            ${pkgs.postgresql_16}/bin/psql -p ${toString cfg.port} -c \
              "ALTER ROLE postgres WITH PASSWORD '$SU_PASS';"
          ''}
        '';
      };

      systemd.services.postgresql-replica-bootstrap = lib.mkIf (!isPrimary) {
        description = "Bootstrap PostgreSQL replica from primary via pg_basebackup";
        before = [ "postgresql.service" ];
        requiredBy = [ "postgresql.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          Group = "postgres";
        };
        script = ''
          if [ -f ${pgDataDir}/PG_VERSION ]; then
            echo "PostgreSQL data directory already exists, skipping bootstrap."
            exit 0
          fi

          echo "Waiting for primary at ${primaryAddr}:${toString cfg.port}..."
          while ! ${pkgs.postgresql_16}/bin/pg_isready -h ${primaryAddr} -p ${toString cfg.port} -q; do
            echo "Primary not ready, retrying in 5s..."
            sleep 5
          done

          echo "Primary is ready. Running pg_basebackup..."
          ${lib.optionalString (cfg.replicationPasswordFile != null) ''
            export PGPASSWORD=$(cat ${cfg.replicationPasswordFile})
          ''}
          ${pkgs.postgresql_16}/bin/pg_basebackup \
            -h ${primaryAddr} \
            -p ${toString cfg.port} \
            -U ${cfg.replicationUser} \
            -D ${pgDataDir} \
            -Fp -Xs -R -P

          echo "Replica bootstrap complete."
        '';
      };

      networking.firewall.allowedTCPPorts = [ cfg.port ];
    };
}
