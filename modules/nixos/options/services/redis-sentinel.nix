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
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the Redis Sentinel cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "rack-a";
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
        default = "jfs-meta";
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
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      nixclyx,
      ...
    }:
    let
      topo = config.psyclyx.topology;
      topoLib = nixclyx.lib.topology lib topo;
      hostname = config.psyclyx.nixos.host;
      labIdx = topo.hosts.${hostname}.labIndex;

      dataNet = topoLib.networks.${cfg.dataNetwork};
      bindAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

      labIndices = map (name: topo.hosts.${name}.labIndex) cfg.clusterNodes;
      sortedIndices = builtins.sort builtins.lessThan labIndices;
      masterIdx = builtins.head sortedIndices;

      isMaster = labIdx == masterIdx;

      masterAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + masterIdx)}";

      allAddrs = map (
        name:
        let
          idx = topo.hosts.${name}.labIndex;
        in
        "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + idx)}"
      ) cfg.clusterNodes;

      sentinelDir = "/var/lib/redis-sentinel";
      sentinelConf = "${sentinelDir}/sentinel.conf";
    in
    {
      services.redis.servers."jfs" = {
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

      # Inject masterauth into the runtime redis config.  The NixOS redis
      # module's prep-conf ExecStartPre generates /run/redis-jfs/nixos.conf
      # (with requirepass from requirePassFile).  We append masterauth to that
      # same file via a second root-level ExecStartPre that runs after it.
      systemd.services.redis-jfs.serviceConfig.ExecStartPre = lib.mkIf (cfg.requirePassFile != null) (
        lib.mkAfter [
          "+${pkgs.writeShellScript "redis-jfs-masterauth" ''
            printf '\nmasterauth %s\n' "$(cat ${cfg.requirePassFile})" >> /run/redis-jfs/nixos.conf
          ''}"
        ]
      );

      systemd.services.redis-sentinel = {
        description = "Redis Sentinel for ${cfg.masterName}";
        after = [
          "network.target"
          "redis-jfs.service"
        ];
        wants = [ "redis-jfs.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = "redis-jfs";
          Group = "redis-jfs";
          StateDirectory = "redis-sentinel";
          ExecStart = "${pkgs.redis}/bin/redis-sentinel ${sentinelConf}";
          Restart = "on-failure";
          RestartSec = 5;
        };

        preStart = ''
          if [ ! -f ${sentinelConf} ]; then
            cat > ${sentinelConf}.tmp <<'SENTINEL_EOF'
          port ${toString cfg.sentinelPort}
          bind ${bindAddr}
          sentinel monitor ${cfg.masterName} ${masterAddr} ${toString cfg.redisPort} ${toString cfg.quorum}
          sentinel down-after-milliseconds ${cfg.masterName} 5000
          sentinel failover-timeout ${cfg.masterName} 10000
          sentinel parallel-syncs ${cfg.masterName} 1
          SENTINEL_EOF

            ${lib.optionalString (cfg.requirePassFile != null) ''
              PASS=$(cat ${cfg.requirePassFile})
              echo "sentinel auth-pass ${cfg.masterName} $PASS" >> ${sentinelConf}.tmp
              echo "requirepass $PASS" >> ${sentinelConf}.tmp
            ''}

            mv ${sentinelConf}.tmp ${sentinelConf}
          fi

          ${lib.optionalString (cfg.requirePassFile != null) ''
            PASS=$(cat ${cfg.requirePassFile})
            ${pkgs.gnused}/bin/sed -i "s/^sentinel auth-pass ${cfg.masterName} .*/sentinel auth-pass ${cfg.masterName} $PASS/" ${sentinelConf}
            if ${pkgs.gnugrep}/bin/grep -q "^requirepass " ${sentinelConf}; then
              ${pkgs.gnused}/bin/sed -i "s/^requirepass .*/requirepass $PASS/" ${sentinelConf}
            else
              echo "requirepass $PASS" >> ${sentinelConf}
            fi
          ''}
        '';
      };

      networking.firewall.allowedTCPPorts = [
        cfg.redisPort
        cfg.sentinelPort
      ];
    };
}
