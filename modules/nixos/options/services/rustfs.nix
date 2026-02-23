{
  path = ["psyclyx" "nixos" "services" "rustfs"];
  description = "RustFS distributed object storage cluster";
  options = {lib, ...}: {
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Hostnames of all nodes in the RustFS cluster.";
    };
    volumesPerNode = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of volume directories per node.";
    };
    dataPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Port for the RustFS data API.";
    };
    consolePort = lib.mkOption {
      type = lib.types.port;
      default = 9001;
      description = "Port for the RustFS management console.";
    };
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "Topology network name for data traffic.";
    };
    consoleNetwork = lib.mkOption {
      type = lib.types.str;
      default = "rack";
      description = "Topology network name for console access.";
    };
    volumeBasePath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/rustfs";
      description = "Base path for RustFS volume directories.";
    };
    credentialsEnvFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to environment file with RUSTFS_ACCESS_KEY and RUSTFS_SECRET_KEY.";
    };
  };

  config = {
    cfg,
    config,
    lib,
    pkgs,
    nixclyx,
    ...
  }: let
    topo = config.psyclyx.topology;
    topoLib = nixclyx.lib.topology lib topo;
    hostname = config.psyclyx.nixos.host;
    labIdx = topo.hosts.${hostname}.labIndex;

    dataNet = topoLib.networks.${cfg.dataNetwork};
    consoleNet = topoLib.networks.${cfg.consoleNetwork};

    dataAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";
    consoleAddr = "${consoleNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

    labIndices = map (name: topo.hosts.${name}.labIndex) cfg.clusterNodes;
    sortedIndices = builtins.sort builtins.lessThan labIndices;
    minIdx = builtins.head sortedIndices;
    maxIdx = lib.last sortedIndices;
    maxVol = cfg.volumesPerNode - 1;
    homeDomain = topo.conventions.homeDomain;

    volumeString = "http://lab-{${toString minIdx}...${toString maxIdx}}.${cfg.dataNetwork}.${homeDomain}:${toString cfg.dataPort}${cfg.volumeBasePath}/vol{0...${toString maxVol}}";

    volumeDirs = builtins.genList (i: "${cfg.volumeBasePath}/vol${toString i}") cfg.volumesPerNode;

    baseEnv = pkgs.writeText "rustfs-cluster.env" ''
      RUSTFS_VOLUMES="${volumeString}"
      RUSTFS_ADDRESS="0.0.0.0:${toString cfg.dataPort}"
      RUSTFS_CONSOLE_ENABLE=true
      RUSTFS_CONSOLE_ADDRESS="${consoleAddr}:${toString cfg.consolePort}"
      RUST_LOG=info
      RUSTFS_OBS_LOG_DIRECTORY="/var/log/rustfs"
    '';
  in {
    services.rustfs = {
      enable = true;
      volumes = volumeString;
      address = "0.0.0.0:${toString cfg.dataPort}";
      consoleAddress = "${consoleAddr}:${toString cfg.consolePort}";
    };

    systemd.services.rustfs.serviceConfig.EnvironmentFile = lib.mkForce (
      [baseEnv]
      ++ lib.optional (cfg.credentialsEnvFile != null) cfg.credentialsEnvFile
    );

    systemd.services.rustfs-volume-setup = {
      description = "Set up RustFS volume directories with bcachefs attributes";
      wantedBy = ["rustfs.service"];
      before = ["rustfs.service"];
      after = ["local-fs.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.concatMapStringsSep "\n" (dir: ''
          mkdir -p ${dir}
          ${pkgs.bcachefs-tools}/bin/bcachefs set-file-option --nocow --data_replicas=1 ${dir}
        '') volumeDirs}
      '';
    };

    networking.firewall.allowedTCPPorts = [cfg.dataPort cfg.consolePort];
  };
}
