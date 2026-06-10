# Egregore → redis-sentinel cluster addressing projection.
{config, lib, ...}: {
  options.psyclyx.nixos.topology.redis-sentinel = {
    enable = lib.mkEnableOption "project egregore cluster topology onto redis-sentinel";
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "Network entity carrying redis traffic.";
    };
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host entity names of the redis sentinel cluster members.";
    };
  };

  config = lib.mkIf config.psyclyx.nixos.topology.redis-sentinel.enable (let
    cfg = config.psyclyx.nixos.topology.redis-sentinel;
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    addrOf = n: lib.attrByPath ["entities" n "host" "addresses" cfg.dataNetwork "ipv4"] "" eg;
    sorted = builtins.sort builtins.lessThan cfg.clusterNodes;
    leader = if sorted == [] then "" else builtins.head sorted;
  in {
    psyclyx.nixos.services.redis-sentinel = {
      bindAddress = addrOf hostname;
      masterAddress = if leader == "" then "" else addrOf leader;
      isMaster = leader != "" && hostname == leader;
    };
  });
}
