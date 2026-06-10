# Egregore → consul cluster addressing projection.
#
# Active whenever `clusterNodes` is non-empty. ha-services.nix
# populates it from HA-group membership; hosts may also set it
# directly.
{config, lib, ...}: {
  options.psyclyx.nixos.derived.consul = {
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "infra";
      description = "Network entity whose host address each member binds + joins on.";
    };
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host entity names of all consul cluster members (this host included).";
    };
  };

  config = lib.mkIf (config.psyclyx.nixos.derived.consul.clusterNodes != []) (let
    cfg = config.psyclyx.nixos.derived.consul;
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    addrOf = n: lib.attrByPath ["entities" n "host" "addresses" cfg.dataNetwork "ipv4"] "" eg;
    others = builtins.filter (n: n != hostname) cfg.clusterNodes;
  in {
    psyclyx.nixos.services.consul = {
      bindAddress = addrOf hostname;
      retryJoinAddresses = map addrOf others;
    };
  });
}
