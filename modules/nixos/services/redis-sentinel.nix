{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "redis-sentinel"
  ];
  description = "Redis server with Sentinel for HA metadata";
  options =
    { lib, ... }:
    {
      serverName = lib.mkOption {
        type = lib.types.str;
        default = "shared";
        description = "Redis server instance name (used for systemd units, user/group).";
      };
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the Redis Sentinel cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "data";
        description = "Topology network name for data traffic.";
      };
      redisPort = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Port for the Redis server.";
      };
      sentinelPort = lib.mkOption {
        type = lib.types.port;
        default = 26379;
        description = "Port for the Redis Sentinel.";
      };
      masterName = lib.mkOption {
        type = lib.types.str;
        default = "shared-meta";
        description = "Sentinel master name.";
      };
      quorum = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Number of Sentinels that must agree for failover.";
      };
      requirePassFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the Redis password.";
      };
      exporters.redis = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the Prometheus redis exporter.";
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

      bindAddr = eg.entities.${hostname}.host.addresses.${cfg.dataNetwork}.ipv4;

      leader = builtins.head (builtins.sort builtins.lessThan cfg.clusterNodes);
      isMaster = hostname == leader;

      masterAddr = eg.entities.${leader}.host.addresses.${cfg.dataNetwork}.ipv4;

      allAddrs = map (name: eg.entities.${name}.host.addresses.${cfg.dataNetwork}.ipv4) cfg.clusterNodes;

      sn = cfg.serverName;
      sentinelDir = "/var/lib/redis-sentinel";
      sentinelConf = "${sentinelDir}/sentinel.conf";
    in
    {
      services.redis.servers.${sn} = {
        enable = true;
        bind = bindAddr;
        port = cfg.redisPort;
        requirePassFile = lib.mkIf (cfg.requirePassFile != null) cfg.requirePassFile;
        settings = lib.mkMerge [
          {
            protected-mode = "no";
          }
          (lib.mkIf (!isMaster) {
            replicaof = "${masterAddr} ${toString cfg.redisPort}";
          })
        ];
      };

      # NixOS redis module doesn't support masterauth; inject after prep-conf
      systemd.services."redis-${sn}".serviceConfig.ExecStartPre = lib.mkIf (cfg.requirePassFile != null) (
        lib.mkAfter [
          "+${pkgs.writeShellScript "redis-${sn}-masterauth" ''
            printf '\nmasterauth %s\n' "$(cat ${cfg.requirePassFile})" >> /run/redis-${sn}/nixos.conf
          ''}"
        ]
      );

      systemd.services.redis-sentinel = {
        description = "Redis Sentinel for ${cfg.masterName}";
        after = [
          "network.target"
          "redis-${sn}.service"
        ];
        wants = [ "redis-${sn}.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = "redis-${sn}";
          Group = "redis-${sn}";
          StateDirectory = "redis-sentinel";
          ExecStart = "${pkgs.redis}/bin/redis-sentinel ${sentinelConf}";
          Restart = "on-failure";
          RestartSec = 5;
        };

        # Reconcile the sentinel.conf from nix on every start. Sentinel
        # persists discovered peers, the elected master, and voting epochs
        # into this file at runtime, so without rewriting it we can never
        # correct stale ring membership (e.g. a peer removed from
        # clusterNodes lingers forever in the gossip table).
        #
        # We preserve `sentinel myid` and `sentinel current-epoch` because
        # losing them would make the daemon look like a fresh sentinel each
        # restart, disrupting voting. Everything else (known-sentinel /
        # known-replica / leader-epoch) is dropped and re-learned from the
        # configured monitor target.
        preStart = ''
          STATIC=${pkgs.writeText "sentinel-static.conf" ''
            port ${toString cfg.sentinelPort}
            bind ${bindAddr}
            sentinel monitor ${cfg.masterName} ${masterAddr} ${toString cfg.redisPort} ${toString cfg.quorum}
            sentinel down-after-milliseconds ${cfg.masterName} 5000
            sentinel failover-timeout ${cfg.masterName} 10000
            sentinel parallel-syncs ${cfg.masterName} 1
          ''}

          PRESERVED=""
          if [ -f ${sentinelConf} ]; then
            PRESERVED=$(${pkgs.gnugrep}/bin/grep -E '^sentinel (myid|current-epoch) ' ${sentinelConf} || true)
          fi

          # install -m sets perms atomically and clobbers any read-only
          # leftover from a prior interrupted run.
          install -m 0640 "$STATIC" ${sentinelConf}.tmp
          if [ -n "$PRESERVED" ]; then
            printf '%s\n' "$PRESERVED" >> ${sentinelConf}.tmp
          fi

          ${lib.optionalString (cfg.requirePassFile != null) ''
            PASS=$(cat ${cfg.requirePassFile})
            echo "sentinel auth-pass ${cfg.masterName} $PASS" >> ${sentinelConf}.tmp
          ''}

          mv ${sentinelConf}.tmp ${sentinelConf}
        '';

        # Once sentinel is responsive, flush the runtime peer/master cache
        # so any stale entries from a previous ring shape are forgotten and
        # re-learned from the freshly-written monitor line.
        postStart = ''
          for i in $(seq 1 30); do
            if ${pkgs.redis}/bin/redis-cli -h ${bindAddr} -p ${toString cfg.sentinelPort} ping 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q PONG; then
              ${pkgs.redis}/bin/redis-cli -h ${bindAddr} -p ${toString cfg.sentinelPort} sentinel reset ${cfg.masterName} >/dev/null || true
              exit 0
            fi
            sleep 1
          done
        '';
      };

      services.prometheus.exporters.redis = lib.mkIf cfg.exporters.redis.enable {
        enable = true;
        openFirewall = true;
        extraFlags = [
          "--redis.addr=${bindAddr}:${toString cfg.redisPort}"
        ];
      };

      psyclyx.nixos.network.ports.redis = [cfg.redisPort cfg.sentinelPort];
    };
}
