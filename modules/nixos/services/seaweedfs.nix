{
  path = ["psyclyx" "nixos" "services" "seaweedfs"];
  description = "SeaweedFS distributed storage cluster";
  options = {lib, ...}: {
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Hostnames of all nodes running volume+filer.";
    };
    masterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Hostnames of nodes running the master (odd count for Raft).";
    };
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "Topology network name for intra-cluster traffic.";
    };
    volumeBasePath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/seaweedfs";
      description = "Data directory root.";
    };
    replication = lib.mkOption {
      type = lib.types.str;
      default = "001";
      description = "Replication strategy (e.g. 001 = 2 copies, same rack).";
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/seaweedfs";
      description = "FUSE mount path.";
    };
    buckets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "S3 buckets to create declaratively.";
    };
    s3 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable S3 gateway.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8333;
        description = "S3 API port.";
      };
      iamConfigFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to IAM JSON config (sops-rendered).";
      };
    };
    webdav = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable WebDAV server.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7333;
        description = "WebDAV server port.";
      };
    };
    filer = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 8888;
        description = "Filer HTTP port.";
      };
      configDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Directory containing filer.toml (sops-rendered).";
      };
    };
    master = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 9333;
        description = "Master HTTP port.";
      };
      volumeSizeLimitMB = lib.mkOption {
        type = lib.types.int;
        default = 30000;
        description = "Max volume file size in MB.";
      };
    };
    volume = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Volume HTTP port.";
      };
      maxVolumes = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Max volumes per server.";
      };
    };
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9327;
      description = "Base metrics port (master=9327, volume=9328, filer=9329, s3=9330).";
    };
    metricsNetwork = lib.mkOption {
      type = lib.types.str;
      default = "rack";
      description = "Topology network for metrics endpoints.";
    };
  };

  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    topo = config.psyclyx.topology;
    topoLib = topo.enriched;
    hostname = config.psyclyx.nixos.host;
    labIdx = topo.hosts.${hostname}.labIndex;

    dataNet = topoLib.networks.${cfg.dataNetwork};
    metricsNet = topoLib.networks.${cfg.metricsNetwork};

    dataAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";
    metricsAddr = "${metricsNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

    isMaster = builtins.elem hostname cfg.masterNodes;

    masterLabIndices = map (name: topo.hosts.${name}.labIndex) cfg.masterNodes;
    sortedMasterIndices = builtins.sort builtins.lessThan masterLabIndices;
    firstMasterIdx = builtins.head sortedMasterIndices;
    isFirstMaster = isMaster && labIdx == firstMasterIdx;

    masterAddrs = map (name: let
      idx = topo.hosts.${name}.labIndex;
    in "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + idx)}")
    cfg.masterNodes;

    masterPeers = lib.concatStringsSep "," (
      map (addr: "${addr}:${toString cfg.master.port}") masterAddrs
    );

    masterGrpcPort = cfg.master.port + 10000;
    volumeGrpcPort = cfg.volume.port + 10000;
    filerGrpcPort = cfg.filer.port + 10000;

    weed = "${pkgs.seaweedfs}/bin/weed";
  in {
    environment.systemPackages = [pkgs.seaweedfs];

    systemd.services.seaweedfs-volume-setup = {
      description = "Set up SeaweedFS volume directories with bcachefs attributes";
      wantedBy = ["multi-user.target"];
      before = ["seaweedfs-master.service" "seaweedfs-volume.service"];
      after = ["local-fs.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for dir in ${cfg.volumeBasePath}/data ${cfg.volumeBasePath}/cache; do
          mkdir -p "$dir"
          ${pkgs.bcachefs-tools}/bin/bcachefs set-file-option --nocow --data_replicas=1 "$dir"
        done
      '';
    };

    systemd.services.seaweedfs-master = lib.mkIf isMaster {
      description = "SeaweedFS master server";
      after = ["network.target" "seaweedfs-volume-setup.service"];
      wants = ["seaweedfs-volume-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          weed "master"
          "-ip=${dataAddr}"
          "-port=${toString cfg.master.port}"
          "-peers=${masterPeers}"
          "-defaultReplication=${cfg.replication}"
          "-volumeSizeLimitMB=${toString cfg.master.volumeSizeLimitMB}"
          "-mdir=${cfg.volumeBasePath}/master"
          "-metricsPort=${toString cfg.metricsPort}"
          "-metricsIp=${metricsAddr}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
      preStart = ''
        mkdir -p ${cfg.volumeBasePath}/master
      '';
    };

    systemd.services.seaweedfs-volume = {
      description = "SeaweedFS volume server";
      after = ["network.target" "seaweedfs-volume-setup.service"]
        ++ lib.optional isMaster "seaweedfs-master.service";
      wants = ["seaweedfs-volume-setup.service"]
        ++ lib.optional isMaster "seaweedfs-master.service";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          weed "volume"
          "-ip=${dataAddr}"
          "-port=${toString cfg.volume.port}"
          "-mserver=${masterPeers}"
          "-dir=${cfg.volumeBasePath}/data"
          "-max=${toString cfg.volume.maxVolumes}"
          "-dataCenter=lab"
          "-rack=rack1"
          "-metricsPort=${toString (cfg.metricsPort + 1)}"
          "-metricsIp=${metricsAddr}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.seaweedfs-filer = {
      description = "SeaweedFS filer server";
      after = ["network.target" "seaweedfs-volume.service"];
      wants = ["seaweedfs-volume.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = lib.mkIf (cfg.filer.configDir != null) [
          "+${pkgs.writeShellScript "seaweedfs-filer-config" ''
            mkdir -p /etc/seaweedfs
            cp ${cfg.filer.configDir}/filer.toml /etc/seaweedfs/filer.toml
          ''}"
        ];
        ExecStart = lib.concatStringsSep " " [
          weed "filer"
          "-ip=${dataAddr}"
          "-port=${toString cfg.filer.port}"
          "-master=${masterPeers}"
          "-metricsPort=${toString (cfg.metricsPort + 2)}"
          "-metricsIp=${metricsAddr}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.seaweedfs-s3 = lib.mkIf cfg.s3.enable {
      description = "SeaweedFS S3 gateway";
      after = ["network.target" "seaweedfs-filer.service"];
      wants = ["seaweedfs-filer.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " ([
          weed "s3"
          "-ip=${dataAddr}"
          "-port=${toString cfg.s3.port}"
          "-filer=${dataAddr}:${toString cfg.filer.port}"
          "-metricsPort=${toString (cfg.metricsPort + 3)}"
          "-metricsIp=${metricsAddr}"
        ] ++ lib.optional (cfg.s3.iamConfigFile != null) "-config=${cfg.s3.iamConfigFile}");
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.seaweedfs-webdav = lib.mkIf cfg.webdav.enable {
      description = "SeaweedFS WebDAV server";
      after = ["network.target" "seaweedfs-filer.service"];
      wants = ["seaweedfs-filer.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          weed "webdav"
          "-ip=${dataAddr}"
          "-port=${toString cfg.webdav.port}"
          "-filer=${dataAddr}:${toString cfg.filer.port}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.seaweedfs-mount = {
      description = "SeaweedFS FUSE mount at ${cfg.mountPoint}";
      after = ["network.target" "seaweedfs-filer.service"];
      wants = ["seaweedfs-filer.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          weed "mount"
          "-filer=${dataAddr}:${toString cfg.filer.port}"
          "-dir=${cfg.mountPoint}"
          "-cacheDir=${cfg.volumeBasePath}/cache"
          "-cacheCapacityMB=10240"
        ];
        ExecStop = "/run/wrappers/bin/umount -l ${cfg.mountPoint}";
        Restart = "on-failure";
        RestartSec = 10;
      };
      preStart = ''
        mkdir -p ${cfg.mountPoint}
      '';
    };

    systemd.services.seaweedfs-bucket-init = lib.mkIf (isFirstMaster && cfg.buckets != []) {
      description = "Create SeaweedFS S3 buckets";
      after = ["seaweedfs-s3.service"];
      wants = ["seaweedfs-s3.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        bucketCmds = lib.concatMapStringsSep "\n" (bucket:
          ''echo "s3.bucket.create -name ${bucket}" | ${weed} shell -master=${dataAddr}:${toString cfg.master.port}''
        ) cfg.buckets;
      in ''
        # Wait for S3 gateway readiness
        for i in $(seq 1 60); do
          if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.s3.port}/status >/dev/null 2>&1; then
            break
          fi
          sleep 2
        done
        ${bucketCmds}
      '';
    };

    networking.firewall.allowedTCPPorts =
      [cfg.volume.port volumeGrpcPort cfg.filer.port filerGrpcPort]
      ++ lib.optionals isMaster [cfg.master.port masterGrpcPort]
      ++ lib.optional cfg.s3.enable cfg.s3.port
      ++ lib.optional cfg.webdav.enable cfg.webdav.port
      ++ [cfg.metricsPort (cfg.metricsPort + 1) (cfg.metricsPort + 2)]
      ++ lib.optional cfg.s3.enable (cfg.metricsPort + 3);
  };
}
