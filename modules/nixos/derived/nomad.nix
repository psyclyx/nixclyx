# Egregore → nomad cluster addressing projection.
{config, lib, ...}: {
  options.psyclyx.nixos.derived.nomad = {
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "infra";
      description = "Network entity carrying nomad's cluster + client traffic.";
    };
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host entity names of all nomad cluster members.";
    };
  };

  config = lib.mkIf (config.psyclyx.nixos.derived.nomad.clusterNodes != []) (let
    cfg = config.psyclyx.nixos.derived.nomad;
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    addrOf = n: lib.attrByPath ["entities" n "host" "addresses" cfg.dataNetwork "ipv4"] "" eg;
    others = builtins.filter (n: n != hostname) cfg.clusterNodes;
  in {
    psyclyx.nixos.services.nomad = {
      bindAddress = addrOf hostname;
      retryJoinAddresses = map addrOf others;
      clientInterface = lib.attrByPath
        ["entities" hostname "host" "interfaces" cfg.dataNetwork "device"] "" eg;
    };
  });
}
