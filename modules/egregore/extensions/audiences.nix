# Reachability audiences — named contexts in which services are reached.
#
# An audience is a primitive abstract concept: a named *reachability
# context* with two intrinsic facts the fleet's projection layer needs:
#
#   - address: a key into host.attrs.addresses on whichever host
#     terminates ingress for the audience. The string is opaque to this
#     module — it just composes with whatever address keys the fleet's
#     hosts use.
#   - defaultIngress: the host (entity name) that runs ingress for
#     services in this audience by default. Per-service `service.ingress`
#     overrides this on a per-(service, audience) basis.
#
# This module owns the abstract concept; concrete audience names, address
# keys, and default ingress assignments are fleet data (tier 3). The
# projection layer reads (audience, ingress host) and composes everything
# else (DNS view, cert source, bind interface) from existing fleet facts.
{
  options = { lib, ... }: {
    audiences = lib.mkOption {
      description = ''
        Attribute set of reachability audiences. Services list the
        audiences they participate in via service.audiences.
      '';
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = ''
              Address key (looked up in host.attrs.addresses on the
              audience's ingress host). Determines the bind interface
              and the DNS A record value.
            '';
          };
          defaultIngress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Default ingress host (entity name) for services in this
              audience. Per-service `service.ingress` may override.
            '';
          };
        };
      });
    };
  };
}
