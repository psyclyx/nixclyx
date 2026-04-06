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
      raftPort = lib.mkOption {
        type = lib.types.port;
        default = 2222;
        description = "Port for Patroni Raft consensus.";
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
      clientNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Topology network for client/HAProxy connections (pg_hba, listen).";
      };
      ssl = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable SSL/TLS for PostgreSQL connections.";
        };
        certFile = lib.mkOption {
          type = lib.types.str;
          default = "/run/openbao-pki/postgres/cert.pem";
        };
        keyFile = lib.mkOption {
          type = lib.types.str;
          default = "/run/openbao-pki/postgres/key.pem";
        };
        caFile = lib.mkOption {
          type = lib.types.str;
          default = "/run/openbao-pki/postgres/ca.pem";
        };
      };
      exporters.postgres = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the Prometheus postgres exporter.";
      };
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
      eg = config.psyclyx.egregore;
      hostname = config.psyclyx.nixos.host;

      dataAddr = eg.entities.${hostname}.host.addresses.${cfg.dataNetwork}.ipv4;
      clientAddr = eg.entities.${hostname}.host.addresses.${cfg.clientNetwork}.ipv4;

      memberAddr = name: eg.entities.${name}.host.addresses.${cfg.dataNetwork}.ipv4;

      dataNetPrefix = eg.entities.${cfg.dataNetwork}.attrs.prefix;
      dataNetPrefixLen = eg.entities.${cfg.dataNetwork}.attrs.prefixLen;
      clientNetPrefix = eg.entities.${cfg.clientNetwork}.attrs.prefix;
      clientNetPrefixLen = eg.entities.${cfg.clientNetwork}.attrs.prefixLen;

      pgHba = [
        "local all all trust"
        "host all all 127.0.0.1/32 md5"
        "host all all ${dataNetPrefix}.0/${toString dataNetPrefixLen} md5"
        "host all all ${clientNetPrefix}.0/${toString clientNetPrefixLen} md5"
        "host replication ${cfg.replicationUser} 127.0.0.1/32 md5"
        "host replication ${cfg.replicationUser} ${dataNetPrefix}.0/${toString dataNetPrefixLen} md5"
      ];

      otherNodes = builtins.filter (name: name != hostname) cfg.clusterNodes;

      raftPartner = map (name:
        "${memberAddr name}:${toString cfg.raftPort}"
      ) otherNodes;
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
          # nixpkgs sets listen from nodeIp; override to bind all interfaces for HAProxy
          restapi.listen = lib.mkForce "0.0.0.0:${toString cfg.restApiPort}";

          # Use built-in Raft for DCS (no external etcd dependency).
          # Override etcd3 to null to prevent nixpkgs from auto-generating it.
          etcd3 = lib.mkForce null;
          raft = {
            data_dir = "/var/lib/patroni/raft";
            self_addr = "${dataAddr}:${toString cfg.raftPort}";
            partner_addrs = raftPartner;
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
                } // lib.optionalAttrs cfg.ssl.enable {
                  ssl = "on";
                  ssl_cert_file = cfg.ssl.certFile;
                  ssl_key_file = cfg.ssl.keyFile;
                  ssl_ca_file = cfg.ssl.caFile;
                };
              };
            };
            initdb = [
              "encoding=UTF-8"
              "data-checksums"
            ];
            pg_hba = pgHba;
          };

          # nixpkgs sets listen from nodeIp; add localhost for local psql
          postgresql = {
            listen = lib.mkForce "${dataAddr},${clientAddr},127.0.0.1:${toString cfg.port}";
            authentication = {
              replication = {
                username = cfg.replicationUser;
              };
              superuser = {
                username = "postgres";
              };
            };
            # Runtime pg_hba (bootstrap.pg_hba only applies on initial creation)
            pg_hba = pgHba;
            parameters = {
              max_connections = 200;
            } // lib.optionalAttrs cfg.ssl.enable {
              ssl = "on";
              ssl_cert_file = cfg.ssl.certFile;
              ssl_key_file = cfg.ssl.keyFile;
              ssl_ca_file = cfg.ssl.caFile;
            };
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

      systemd.tmpfiles.rules = [
        "d /run/postgresql 0755 patroni patroni -"
        "d /var/lib/patroni/raft 0700 patroni patroni -"
      ];

      systemd.services.patroni = {
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

      # bootstrap.dcs only applies on initial creation; sync at runtime
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
          ready=0
          for i in $(seq 1 30); do
            if curl -sf http://localhost:${toString cfg.restApiPort}/config > /dev/null 2>&1; then
              ready=1
              break
            fi
            sleep 2
          done
          if [ "$ready" -eq 0 ]; then
            echo "patroni REST API not available after 60s, skipping DCS sync" >&2
            exit 0
          fi
          curl -sf -XPATCH -H 'Content-Type: application/json' \
            -d '${dcsConfig}' \
            http://localhost:${toString cfg.restApiPort}/config
        '';
      };

      services.prometheus.exporters.postgres = lib.mkIf cfg.exporters.postgres.enable {
        enable = true;
        openFirewall = true;
      };

      psyclyx.nixos.network.ports.patroni = [cfg.port cfg.restApiPort cfg.raftPort];
    };
}
