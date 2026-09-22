# Entity type: route.
#
# A static route, as a fact in its own right rather than something
# inferred from a device's other settings.
#
# Three refs, which are the three things every routing table names:
#
#   refs.on    the device that installs it
#   refs.via   the next hop — an entity, not an address
#   refs.over  the network the next hop is reached on
#
# `over` is not redundant with `via`. Two devices commonly share several
# networks, so "via that router" doesn't say which of its addresses to
# use; the link is a separate fact, the same way `ip route add DST via
# GW dev LINK` names one. It also means moving a route onto a different
# link is an edit to this entity and nothing else.
#
# The next hop is resolved through `attrs.addresses` on whatever `via`
# names, so a route doesn't care whether it points at a host, a switch,
# or anything else that reports the addresses it holds.
{
  egregoreType = { lib, ... }: {
    name = "route";
    description = "A static route installed by a device.";

    options = {
      dst = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Destination prefix, e.g. "0.0.0.0/0" or "::/0". The address
          family follows from it; a route with a ":" in its destination
          is a v6 route.
        '';
      };
      distance = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Administrative distance. Null leaves the platform default.";
      };
      disabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Installed but inactive. Kept as a declared placeholder on
          devices that shouldn't route yet — an L2-only switch carries
          its default route disabled rather than not carrying it.
        '';
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

    attrs = name: entity: top: let
      r = entity.route;
      refs = entity.refs or {};
      viaName = refs.via or null;
      overName = refs.over or null;
      via = if viaName == null then null else top.entities.${viaName} or null;
      isV6 = lib.hasInfix ":" r.dst;
      # The next hop's address on the network this route crosses. Read
      # from the resolved address view, so it works whether the next hop
      # declares the address or derives it from being that network's
      # gateway.
      viaAddrs =
        if via == null || overName == null then {}
        else (via.attrs.addresses or {}).${overName} or {};
    in {
      inherit (r) dst disabled;
      family = if isV6 then "ipv6" else "ipv4";
      gateway = if isV6 then viaAddrs.ipv6 or null else viaAddrs.ipv4 or null;
      label = "${r.dst} via ${if viaName == null then "?" else viaName}";
    };

    assertions = name: entity: top: let
      refs = entity.refs or {};
      over = refs.over or null;
      on = refs.on or null;
    in
      [
        {
          assertion = entity.route.dst != "";
          message = "route '${name}' has no dst";
        }
        {
          assertion = on != null;
          message = "route '${name}' has no refs.on — nothing installs it";
        }
        {
          assertion = refs ? via;
          message = "route '${name}' has no refs.via — no next hop";
        }
        {
          assertion = over != null;
          message =
            "route '${name}' has no refs.over — which network the next "
            + "hop is reached on can't be inferred when two devices share "
            + "more than one";
        }
      ]
      ++ lib.optional (over != null) {
        assertion = (top.entities.${over}.type or null) == "network";
        message = "route '${name}' refs.over → '${over}' is not a network";
      }
      # A next hop we can't resolve an address for is a route that
      # silently doesn't get emitted, which is worse than one that fails.
      ++ lib.optional (over != null && refs ? via) {
        assertion = entity.attrs.gateway != null;
        message =
          "route '${name}': next hop '${refs.via}' has no "
          + "${entity.attrs.family} address on '${over}'";
      };
  };
}
