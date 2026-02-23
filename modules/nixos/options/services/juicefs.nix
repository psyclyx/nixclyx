{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "juicefs"
  ];
  description = "JuiceFS POSIX filesystem backed by RustFS";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the JuiceFS cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "data";
        description = "Topology network name for data traffic.";
      };
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/jfs";
        description = "Path where JuiceFS will be mounted.";
      };
      volumeName = lib.mkOption {
        type = lib.types.str;
        default = "psyclyx-jfs";
        description = "Name of the JuiceFS volume.";
      };
      sentinelMasterName = lib.mkOption {
        type = lib.types.str;
        default = "jfs-meta";
        description = "Redis Sentinel master name for metadata.";
      };
      sentinelPort = lib.mkOption {
        type = lib.types.port;
        default = 26379;
        description = "Port for Redis Sentinel instances.";
      };
      redisDatabase = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Redis database number for JuiceFS metadata.";
      };
      s3Bucket = lib.mkOption {
        type = lib.types.str;
        default = "juicefs";
        description = "S3 bucket name in RustFS for JuiceFS data.";
      };
      cacheDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/cache/juicefs";
        description = "Local cache directory for JuiceFS.";
      };
      cacheSizeMB = lib.mkOption {
        type = lib.types.int;
        default = 10240;
        description = "Local cache size in megabytes.";
      };
      credentialsEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to environment file with ACCESS_KEY, SECRET_KEY, and META_PASSWORD.";
      };
      metricsPort = lib.mkOption {
        type = lib.types.port;
        default = 9567;
        description = "Port for the built-in JuiceFS Prometheus metrics endpoint.";
      };
      metricsNetwork = lib.mkOption {
        type = lib.types.str;
        default = "rack";
        description = "Topology network name for the metrics endpoint bind address.";
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
      localAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

      metricsNet = topoLib.networks.${cfg.metricsNetwork};
      metricsAddr = "${metricsNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

      labIndices = map (name: topo.hosts.${name}.labIndex) cfg.clusterNodes;
      sortedIndices = builtins.sort builtins.lessThan labIndices;
      firstIdx = builtins.head sortedIndices;

      isFirstNode = labIdx == firstIdx;

      sentinelAddrs = lib.concatStringsSep "," (
        map (
          name:
          let
            idx = topo.hosts.${name}.labIndex;
          in
          "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + idx)}"
        ) cfg.clusterNodes
      );

      metaUrl = "redis://${cfg.sentinelMasterName},${sentinelAddrs}:${toString cfg.sentinelPort}/${toString cfg.redisDatabase}";
      s3Endpoint = "http://127.0.0.1:9000";
      s3Storage = "s3";

      juicefs = "${pkgs.juicefs}/bin/juicefs";
    in
    {
      environment.systemPackages = [ pkgs.juicefs ];

      systemd.services.juicefs-format = {
        description = "Format JuiceFS volume (first node only)";
        after = [
          "network.target"
          "redis-sentinel.service"
          "redis-jfs.service"
        ];
        wants = [
          "redis-sentinel.service"
          "redis-jfs.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = lib.mkIf (cfg.credentialsEnvFile != null) cfg.credentialsEnvFile;
        };
        script =
          if isFirstNode then
            ''
              if ${juicefs} status "${metaUrl}" 2>/dev/null; then
                echo "JuiceFS volume already formatted."
                exit 0
              fi
              echo "Formatting JuiceFS volume ${cfg.volumeName}..."
              ${juicefs} format \
                --storage ${s3Storage} \
                --bucket ${s3Endpoint}/${cfg.s3Bucket} \
                "${metaUrl}" \
                ${cfg.volumeName}
            ''
          else
            ''
              echo "Not the first node, skipping format."
              exit 0
            '';
      };

      systemd.services.juicefs-mount = {
        description = "Mount JuiceFS filesystem at ${cfg.mountPoint}";
        after = [
          "juicefs-format.service"
          "network.target"
          "redis-sentinel.service"
        ];
        wants = [
          "juicefs-format.service"
          "redis-sentinel.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " [
            juicefs
            "mount"
            "--cache-dir"
            cfg.cacheDir
            "--cache-size"
            (toString cfg.cacheSizeMB)
            "--metrics"
            "${metricsAddr}:${toString cfg.metricsPort}"
            "--no-bgjob"
            metaUrl
            cfg.mountPoint
          ];
          ExecStop = "/run/wrappers/bin/umount -l ${cfg.mountPoint}";
          EnvironmentFile = lib.mkIf (cfg.credentialsEnvFile != null) cfg.credentialsEnvFile;
          Restart = "on-failure";
          RestartSec = 10;
        };
        preStart = ''
          mkdir -p ${cfg.mountPoint}
          mkdir -p ${cfg.cacheDir}
        '';
      };

    };
}
