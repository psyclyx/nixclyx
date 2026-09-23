# Egregore → tang server projection.
#
# For each service of kind `tang` whose backend exposure sits on the
# running host, enables services.tang. Bind address is the service's
# resolved backend address; the ACL covers the backend's own network
# (the address key of its exposure's first scope) plus any extra
# networks in `service.reach`.
#
# Writes services.tang directly because there's no psyclyx-tier wrapper
# around it — tang's NixOS options are small enough that an intermediate
# generic module would just be passthrough. The mechanism (keys, unit)
# is host config; the fleet only declares that the service exists, where
# it runs, and who may reach it.
{config, lib, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;

  myTangs = lib.filterAttrs (
    _: e:
    e.type == "service"
    && (e.service.kind or null) == "tang"
    && (e.service.backend.host.target or null) == hostname
  ) eg.entities;

  netCidr = name: let
    a = lib.attrByPath ["entities" name "attrs"] {} eg;
  in lib.optionalString (a ? network4 && a ? prefixLen)
    "${a.network4}/${toString a.prefixLen}";

  # First (and currently only) tang service on this host. Multiple tangs
  # would need port disambiguation; defer until we have a real case.
  myTang = if myTangs == {} then null
    else lib.head (lib.attrValues myTangs);
in {
  config = lib.mkIf (myTang != null) (let
    s = myTang.service;
    bindAddr = myTang.attrs.resolvedAddress;
    # The backend's own network is the address key of its exposure's
    # first scope (scopes map to address keys; a network-named scope is
    # its own key) — the exposure replaces the old `backend.host.network`.
    backendScope =
      let exp = eg.entities.${s.backend.host.target}.exposures.${s.backend.host.exposure} or null;
      in if exp == null || exp.scopes == [] then null else lib.head exp.scopes;
    backendAddrKey =
      if backendScope == null then null
      else (eg.scopes.${backendScope} or {}).address or backendScope;
    aclCidrs = lib.filter (c: c != "")
      (map netCidr (lib.optional (backendAddrKey != null) backendAddrKey ++ (s.reach or [])));
  in {
    services.tang = lib.mkIf (bindAddr != null) {
      enable = true;
      listenStream = [ "${bindAddr}:${toString myTang.attrs.resolvedPort}" ];
      ipAddressAllow = aclCidrs;
    };
  });
}
