# Egregore → patroni cluster addressing projection.
{config, lib, ...}: {
  options.psyclyx.nixos.derived.patroni = {
    enable = lib.mkEnableOption "project egregore cluster topology onto patroni";
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "Network entity carrying raft + postgres replication.";
    };
    clientNetwork = lib.mkOption {
      type = lib.types.str;
      default = "infra";
      description = "Network entity for client/HAProxy connections.";
    };
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host entity names of the patroni cluster members.";
    };
  };

  config = lib.mkIf config.psyclyx.nixos.derived.patroni.enable (let
    cfg = config.psyclyx.nixos.derived.patroni;
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    addrOn = net: n: lib.attrByPath ["entities" n "host" "addresses" net "ipv4"] "" eg;
    netCidr = net: let
      attrs = lib.attrByPath ["entities" net "attrs"] {} eg;
      net4 = attrs.network4 or "";
      plen = attrs.prefixLen or 0;
    in if net4 == "" then "" else "${net4}/${toString plen}";
    others = builtins.filter (n: n != hostname) cfg.clusterNodes;
  in {
    psyclyx.nixos.services.patroni = {
      dataAddress = addrOn cfg.dataNetwork hostname;
      clientAddress = addrOn cfg.clientNetwork hostname;
      otherMemberAddresses = map (addrOn cfg.dataNetwork) others;
      pgHbaSubnets = builtins.filter (s: s != "") [ (netCidr cfg.dataNetwork) (netCidr cfg.clientNetwork) ];
    };
  });
}
