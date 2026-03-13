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
      fleet = config.psyclyx.fleet;
      hostname = config.psyclyx.nixos.host;

      dataAddr = fleet.hostAddress hostname cfg.dataNetwork;
      rackAddr = fleet.hostAddress hostname "rack";

      memberAddr = name: fleet.hostAddress name cfg.dataNetwork;

      dataNetPrefix = fleet.networkPrefix cfg.dataNetwork;
      dataNetPrefixLen = fleet.networkPrefixLen cfg.dataNetwork;
      rackNetPrefix = fleet.networkPrefix "rack";
      rackNetPrefixLen = fleet.networkPrefixLen "rack";

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
              check_timeline = true;
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
              "host all all ${dataNetPrefix}.0/${toString dataNetPrefixLen} md5"
              "host all all ${rackNetPrefix}.0/${toString rackNetPrefixLen} md5"
              "host replication ${cfg.replicationUser} 127.0.0.1/32 md5"
              "host replication ${cfg.replicationUser} ${dataNetPrefix}.0/${toString dataNetPrefixLen} md5"
            ];
          };

          # Override listen to also bind localhost (for local psql access).
          # nixpkgs sets listen/connect_address from nodeIp — connect_address is correct.
          postgresql = {
            listen = lib.mkForce "${dataAddr},${rackAddr},127.0.0.1:${toString cfg.port}";
            authentication = {
              replication = {
                username = cfg.replicationUser;
              };
              superuser = {
                username = "postgres";
              };
            };
            # Patroni manages pg_hba.conf from this list (bootstrap.pg_hba only
            # applies during initial cluster creation).
            pg_hba = [
              "local all all trust"
              "host all all 127.0.0.1/32 md5"
              "host all all ${dataNetPrefix}.0/${toString dataNetPrefixLen} md5"
              "host all all ${rackNetPrefix}.0/${toString rackNetPrefixLen} md5"
              "host replication ${cfg.replicationUser} 127.0.0.1/32 md5"
              "host replication ${cfg.replicationUser} ${dataNetPrefix}.0/${toString dataNetPrefixLen} md5"
            ];
            parameters = {
              max_connections = 200;
            };
            # Automatically re-clone from the leader when a replica's timeline has
            # diverged (e.g. after failovers) and pg_rewind isn't possible.
            remove_data_directory_on_diverged_timelines = true;
            remove_data_directory_on_rewind_failure = true;
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
        serviceConfig.ExecStartPre = let
          requiredFiles = lib.filter (f: f != null) [
            cfg.replicationPasswordFile
            cfg.superuserPasswordFile
          ];
          checkScript = pkgs.writeShellScript "check-patroni-secrets" ''
            ${lib.concatMapStringsSep "\n" (f: ''
              if [ ! -f ${lib.escapeShellArg f} ]; then
                echo "patroni: required secret missing: ${f}" >&2
                exit 1
              fi
            '') requiredFiles}
          '';
        in lib.mkIf (requiredFiles != []) [checkScript];
      };

      # Sync DCS configuration from the module into the live cluster.
      # bootstrap.dcs only applies on initial cluster creation — this
      # oneshot idempotently patches the running DCS via Patroni's REST API.
      systemd.services.patroni-dcs-sync = {
        description = "Sync Patroni DCS configuration";
        after = ["patroni.service"];
        requires = ["patroni.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [pkgs.curl];
        script = let
          dcsConfig = builtins.toJSON {
            check_timeline = true;
          };
        in ''
          # Wait for Patroni REST API to become available
          for i in $(seq 1 30); do
            if curl -sf http://localhost:${toString cfg.restApiPort}/config > /dev/null 2>&1; then
              break
            fi
            sleep 2
          done
          curl -sf -XPATCH -H 'Content-Type: application/json' \
            -d '${dcsConfig}' \
            http://localhost:${toString cfg.restApiPort}/config
        '';
      };

      psyclyx.nixos.network.ports.patroni = [cfg.port cfg.restApiPort];
    };
}
