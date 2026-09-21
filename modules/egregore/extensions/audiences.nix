# Reachability audiences — named scopes in which services are reached.
#
# An audience is a primitive abstract concept: a named *reachability
# scope*. Its one intrinsic fact is the address key it names, looked up
# in host.attrs.addresses. The string is opaque to this module — it just
# composes with whatever address keys the fleet's hosts use.
#
# Who terminates ingress for an audience is not an audience fact: it is
# a service (`service.proxy`), the way a thing that forwards is a node. A
# service is proxied on the proxy that serves its audience, overridable
# per service; an audience no proxy serves is reached directly at the
# service's backend. Keeping the proxy out of the context is what lets the
# same scope be served by different boxes (or by none) without rewriting
# the scope.
#
# This module owns the abstract concept; concrete audience names and
# address keys are fleet data (tier 3).
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
              Address key (looked up in host.attrs.addresses on a host
              that terminates ingress for this audience). Determines the
              bind interface and the DNS A record value.
            '';
          };
        };
      });
    };
  };
}
