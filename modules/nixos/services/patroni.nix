{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "patroni"
  ];
  description = "Patroni-managed PostgreSQL HA cluster";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the Patroni cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "data";
        description = "Topology network name for data traffic.";
      };
      scope = lib.mkOption {
        type = lib.types.str;
        default = "psyclyx-pg";
        description = "Patroni cluster scope (name).";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "Port for the PostgreSQL server.";
      };
      restApiPort = lib.mkOption {
        type = lib.types.port;
        default = 8008;
        description = "Port for the Patroni REST API.";
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
      rackNet = topoLib.networks."rack";
      dataAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

      memberAddr = name: let
        idx = topo.hosts.${name}.labIndex;
      in "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + idx)}";

      otherNodes = builtins.filter (name: name != hostname) cfg.clusterNodes;

      etcdHosts = lib.concatStringsSep "," (map (name:
        "${memberAddr name}:2379"
      ) cfg.clusterNodes);
    in
    {
      services.patroni = {
        enable = true;
        postgresqlPackage = pkgs.postgresql_16;
        postgresqlPort = cfg.port;
        inherit (cfg) scope;
        name = hostname;
        nodeIp = dataAddr;
        otherNodesIps = map memberAddr otherNodes;
        restApiPort = cfg.restApiPort;
        softwareWatchdog = false;

        settings = {
          # Override listen to bind on all interfaces (HAProxy checks from rack network)
          # nixpkgs sets listen/connect_address from nodeIp — connect_address is correct,
          # but listen needs 0.0.0.0 so we mkForce it.
          restapi.listen = lib.mkForce "0.0.0.0:${toString cfg.restApiPort}";

          etcd3 = {
            hosts = etcdHosts;
          };

          bootstrap = {
            dcs = {
              ttl = 30;
              loop_wait = 10;
              retry_timeout = 10;
              maximum_lag_on_failover = 1048576;
              postgresql = {
                use_pg_rewind = true;
                use_slots = true;
                parameters = {
                  wal_level = "replica";
                  hot_standby = "on";
                  max_connections = 200;
                  max_wal_senders = 10;
                  max_replication_slots = 10;
                  wal_log_hints = "on";
                };
              };
            };
            initdb = [
              "encoding=UTF-8"
              "data-checksums"
            ];
            pg_hba = [
              "local all all trust"
              "host all all 127.0.0.1/32 md5"
              "host all all ${dataNet.prefix}.0/${toString dataNet.prefixLen} md5"
              "host all all ${rackNet.prefix}.0/${toString rackNet.prefixLen} md5"
              "host replication ${cfg.replicationUser} 127.0.0.1/32 md5"
              "host replication ${cfg.replicationUser} ${dataNet.prefix}.0/${toString dataNet.prefixLen} md5"
            ];
          };

          # Override listen to also bind localhost (for local psql access).
          # nixpkgs sets listen/connect_address from nodeIp — connect_address is correct.
          postgresql = {
            listen = lib.mkForce "${dataAddr},127.0.0.1:${toString cfg.port}";
            authentication = {
              replication = {
                username = cfg.replicationUser;
              };
              superuser = {
                username = "postgres";
              };
            };
            parameters = {
              max_connections = 200;
            };
          };
        };

        environmentFiles = lib.mkMerge [
          (lib.mkIf (cfg.replicationPasswordFile != null) {
            PATRONI_REPLICATION_PASSWORD = cfg.replicationPasswordFile;
          })
          (lib.mkIf (cfg.superuserPasswordFile != null) {
            PATRONI_SUPERUSER_PASSWORD = cfg.superuserPasswordFile;
          })
        ];
      };

      # Patroni manages PostgreSQL — do not enable the NixOS postgresql service.
      # services.postgresql.enable is intentionally not set.

      # Create /run/postgresql for the PostgreSQL Unix socket lock file.
      systemd.tmpfiles.rules = [
        "d /run/postgresql 0755 patroni patroni -"
      ];

      systemd.services.patroni = {
        after = ["etcd.service"];
        wants = ["etcd.service"];
      };

      networking.firewall.allowedTCPPorts = [
        cfg.port
        cfg.restApiPort
      ];
    };
}
