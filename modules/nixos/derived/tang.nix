# Egregore → tang server projection.
#
# For each tang-server entity whose refs.host is the running host,
# enables services.tang. Bind address comes from the host's address
# on the entity's `network`; the ACL list covers `network` plus any
# `aclNetworks` extras.
#
# Writes services.tang directly because there's no psyclyx-tier
# wrapper around it — tang's NixOS options are already small enough
# that an intermediate generic module would just be passthrough.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;

  myTangs = lib.filterAttrs (
    _: e: e.type == "tang-server" && (e.refs.host or null) == hostname
  ) eg.entities;

  netCidr = name: let
    a = lib.attrByPath ["entities" name "attrs"] {} eg;
  in lib.optionalString (a ? network4 && a ? prefixLen)
    "${a.network4}/${toString a.prefixLen}";

  addrOn = network: lib.attrByPath
    ["entities" hostname "host" "addresses" network "ipv4"] "" eg;

  # First (and currently only) tang-server on this host. Multiple
  # tangs would need port disambiguation; defer until we have a real
  # case.
  myTang = if myTangs == {} then null
    else lib.head (lib.attrValues myTangs);
in {
  config = lib.mkIf (myTang != null) (let
    t = myTang.tang-server;
    bindAddr = addrOn t.network;
    aclCidrs = lib.filter (s: s != "")
      (map netCidr ([ t.network ] ++ t.aclNetworks));
  in {
    services.tang = lib.mkIf (bindAddr != "") {
      enable = true;
      listenStream = [ "${bindAddr}:${toString t.port}" ];
      ipAddressAllow = aclCidrs;
    };
  });
}
