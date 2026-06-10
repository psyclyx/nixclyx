# Egregore → seaweedfs cluster addressing projection.
{config, lib, ...}: {
  options.psyclyx.nixos.derived.seaweedfs = {
    enable = lib.mkEnableOption "project egregore cluster topology onto seaweedfs";
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "Network entity carrying intra-cluster seaweedfs traffic.";
    };
    metricsNetwork = lib.mkOption {
      type = lib.types.str;
      default = "infra";
      description = "Network entity carrying prometheus scrapes.";
    };
    masterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host entity names that run the master (Raft requires odd count).";
    };
  };

  config = lib.mkIf config.psyclyx.nixos.derived.seaweedfs.enable (let
    cfg = config.psyclyx.nixos.derived.seaweedfs;
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    dataAddrOf = n: lib.attrByPath ["entities" n "host" "addresses" cfg.dataNetwork "ipv4"] "" eg;
    metricsAddrOf = n: lib.attrByPath ["entities" n "host" "addresses" cfg.metricsNetwork "ipv4"] "" eg;
    isMaster = builtins.elem hostname cfg.masterNodes;
    firstMaster =
      if cfg.masterNodes == [] then null
      else builtins.head (builtins.sort builtins.lessThan cfg.masterNodes);
  in {
    psyclyx.nixos.services.seaweedfs = {
      dataAddress = dataAddrOf hostname;
      metricsAddress = metricsAddrOf hostname;
      masterAddresses = map dataAddrOf cfg.masterNodes;
      inherit isMaster;
      isFirstMaster = isMaster && hostname == firstMaster;
    };
  });
}
