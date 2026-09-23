# Egregore → onward IPv6 prefix delegation.
#
# Reads `prefix-delegation` entities whose `refs.from` names this host,
# and configures the binder to serve them. Everything it needs is
# already in the graph: which slice, which link the receiving router is
# on, and what address to route the slice to.
#
# The next hop is the receiver's *declared* address on that link rather
# than anything derived from the delegation — a static ULA on a transit
# /30 — so the route survives the renumber that changes the prefix.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host or null;
  me = if hostname == null then null else eg.entities.${hostname}.host or null;

  delegations = lib.filterAttrs
    (_: e: e.type == "prefix-delegation" && (e.refs.from or null) == hostname)
    (eg.entities or {});

  mkDownstream = _: d: let
    over = d.refs.over;
    receiver = eg.entities.${d.refs.to};
    addrs = (receiver.addresses or {}).${over} or {};
  in {
    name = d.refs.to;
    value = {
      inherit (d) subnetId prefixLength;
      interface = me.interfaces.${over}.device;
      via = addrs.ipv6;
    };
  };
in {
  config = lib.mkIf (hostname != null && delegations != {}) {
    psyclyx.nixos.network.prefixDelegation = {
      enable = true;
      downstream = builtins.listToAttrs
        (lib.mapAttrsToList mkDownstream delegations);
    };

    # The pool the binder keeps current has to exist for it to find, and
    # the marker is how it's found — by name rather than by subnet id or
    # position, so Kea's config can be reordered around it.
    psyclyx.nixos.services.dhcp.delegations = lib.mapAttrs'
      (_: d: lib.nameValuePair d.refs.to {
        network = d.refs.over;
        inherit (d) prefixLength;
      })
      delegations;
  };
}
