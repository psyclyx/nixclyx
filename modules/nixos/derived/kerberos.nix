# Egregore globals.kerberos + nfs-export/host data → KDC + client wiring.
#
# Fully declarative: principal list comes from data, the primary KDC
# provisions any principal missing from its DB on each activation
# and pushes keytabs to OpenBao. Clients pick up their krb5.conf
# from this projection too.
#
# Principal sources:
#  - `host.kerberos.enable = true` → `host/<host.attrs.fqdns.<net>>@REALM`
#  - any host that consumes an nfs-export with `sec != "sys"` →
#    same host principal (auto-include)
#  - every nfs-export with `sec != "sys"` → `nfs/<producer.fqdns.<net>>@REALM`
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host or null;
  kerb = eg.kerberos or {};
  enabled = (kerb.realm or "") != "";

  primary = kerb.primary or null;
  secondaries = kerb.secondaries or [];
  kdcNet = kerb.kdcNetwork or "vpn";
  realm = kerb.realm or "";

  entities = eg.entities or {};

  # Address of a host on the configured KDC network.
  addressOf = name:
    let
      h = entities.${name} or null;
      addr = lib.attrByPath ["attrs" "addresses" kdcNet "ipv4"] null h;
    in
    addr;

  primaryAddr = if primary != null then addressOf primary else null;
  secondaryAddrs = lib.filter (a: a != null) (map addressOf secondaries);
  kdcs = lib.filter (a: a != null) ([ primaryAddr ] ++ secondaryAddrs);

  isPrimary = enabled && hostname != null && primary == hostname;
  isSecondary = enabled && hostname != null && builtins.elem hostname secondaries;

  # FQDN of a host on the network it's identified by for Kerberos.
  hostFqdn = name:
    let
      h = entities.${name} or null;
      net = lib.attrByPath ["host" "kerberos" "fqdnNetwork"] "vpn" h;
      fqdn = lib.attrByPath ["attrs" "fqdns" net] null h;
    in
    fqdn;

  # All NFS exports requiring Kerberos.
  authedExports = lib.filterAttrs
    (_: e: e.type == "nfs-export" && (e.nfs-export.sec or "sys") != "sys")
    entities;

  # Hosts that need a host/<fqdn> principal:
  #  - explicitly opted in via host.kerberos.enable
  #  - any consumer of an authed NFS export
  optInHosts = lib.attrNames (lib.filterAttrs
    (_: e: e.type == "host" && (e.host.kerberos.enable or false))
    entities);

  nfsConsumerHosts = lib.unique (lib.concatLists
    (lib.mapAttrsToList (_: e: e.nfs-export.consumers or []) authedExports));

  hostsNeedingPrincipal = lib.unique (optInHosts ++ nfsConsumerHosts);

  hostPrincipals = lib.filter (p: p != null)
    (map (h:
      let fqdn = hostFqdn h; in
      if fqdn == null then null else "host/${fqdn}@${realm}"
    ) hostsNeedingPrincipal);

  # nfs/<producer.fqdn>@REALM for each authed export.
  nfsPrincipals = lib.filter (p: p != null)
    (lib.mapAttrsToList (_: e:
      let
        producer = e.refs.producer or null;
        fqdn = if producer != null then hostFqdn producer else null;
      in
      if fqdn == null then null else "nfs/${fqdn}@${realm}"
    ) authedExports);

  # Human user principals (`<user>@REALM`). Not entity-derived — a
  # person accessing a krb5* NFS mount under their own uid needs one.
  userPrincipals = map (u: "${u}@${realm}") (kerb.userPrincipals or []);

  allPrincipals = lib.unique (hostPrincipals ++ nfsPrincipals ++ userPrincipals);

  # Secondary peer hostnames the primary should kprop to. We use the
  # KDC-network FQDN so kpropd hostname checks line up.
  secondaryPeers = lib.filter (a: a != null) (map hostFqdn secondaries);
in {
  config = lib.mkMerge [
    # Every host gets the client config when Kerberos is enabled and
    # we have at least one KDC address.
    (lib.mkIf (enabled && kdcs != []) {
      psyclyx.nixos.services.kerberos-client = {
        enable = true;
        realm = kerb.realm;
        kdcs = kdcs;
        domainRealmMappings = kerb.domainRealmMappings or {};
      };
    })

    # KDC role: primary.
    (lib.mkIf isPrimary {
      psyclyx.nixos.services.kerberos-kdc = {
        enable = true;
        realm = kerb.realm;
        role = "primary";
        principals = allPrincipals;
        secondaries = secondaryPeers;
        # masterPasswordFile + openbao endpoint set host-side
        # (secrets are a host concern).
      };
    })

    # KDC role: secondary.
    (lib.mkIf isSecondary {
      psyclyx.nixos.services.kerberos-kdc = {
        enable = true;
        realm = kerb.realm;
        role = "secondary";
      };
    })
  ];
}
