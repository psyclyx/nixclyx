# Entity type: prefix delegation.
#
# One router hands a slice of the IPv6 prefix it was delegated to
# another. Three refs, the same shape a route uses:
#
#   refs.from  the router holding the upstream delegation
#   refs.to    the router receiving a slice
#   refs.over  the network the two meet on
#
# Both ends read this one entity: the delegating router derives the pool
# it serves and the route back, and the receiving router derives its
# DHCPv6 client. Neither invents its half.
#
# No prefix appears here, only the plan for slicing whatever arrives.
# `subnetId` counts in units of `prefixLength`, so with a /60 upstream
# and prefixLength 61, subnetId 1 is the upper half. Which half is a
# decision; which addresses that turns out to mean is not.
{
  egregoreType = { lib, ... }: {
    name = "prefix-delegation";
    description = "A slice of a received IPv6 prefix, delegated onward.";

    options = {
      subnetId = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Which slice of the upstream prefix, in units of prefixLength.";
      };
      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 64;
        description = "Size of the delegated slice.";
      };
    };

    deriveOptions = {
      subnetId = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Which slice of the upstream prefix (mirrors `prefix-delegation.subnetId`).";
      };
      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Size of the delegated slice (mirrors `prefix-delegation.prefixLength`).";
      };
      label = lib.mkOption { type = lib.types.str; };
    };

    derive = name: entity: _egregore: let
      refs = entity.refs or {};
    in {
      inherit (entity.prefix-delegation) subnetId prefixLength;
      label = "/${toString entity.prefix-delegation.prefixLength} to ${refs.to or "?"}";
    };

    assertions = name: entity: egregore: let
      refs = entity.refs or {};
      over = refs.over or null;
    in [
      { assertion = refs ? from;
        message = "prefix-delegation '${name}' has no refs.from"; }
      { assertion = refs ? to;
        message = "prefix-delegation '${name}' has no refs.to"; }
      { assertion = over != null;
        message = "prefix-delegation '${name}' has no refs.over — the two "
          + "routers may share several networks, and which one carries the "
          + "delegation decides the next hop for the slice"; }
    ] ++ lib.optional (over != null) {
      assertion = (egregore.entities.${over}.network or null) != null;
      message = "prefix-delegation '${name}' refs.over → '${over}' is not a network";
    };
  };
}
