# Egregore → openbao raft cluster addressing projection.
{config, lib, ...}: {
  options.psyclyx.nixos.derived.openbao-cluster = {
    enable = lib.mkEnableOption "project egregore cluster topology onto openbao";
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "infra";
      description = "Network entity carrying openbao raft + API traffic.";
    };
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host entity names of all openbao cluster members.";
    };
  };

  config = lib.mkIf config.psyclyx.nixos.derived.openbao-cluster.enable (let
    cfg = config.psyclyx.nixos.derived.openbao-cluster;
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    addrOf = n: lib.attrByPath ["entities" n "host" "addresses" cfg.dataNetwork "ipv4"] "" eg;
    others = builtins.filter (n: n != hostname) cfg.clusterNodes;
  in {
    psyclyx.nixos.services.openbao = {
      bindAddress = addrOf hostname;
      retryJoinAddresses = map addrOf others;
    };
  });
}
