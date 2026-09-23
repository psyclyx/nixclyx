# Reachability scopes — named places in which services are reached.
#
# A scope is a primitive abstract concept: a named *reachability
# scope*. Its one intrinsic fact is the address key it names, looked up
# in the `addresses` aspect. The string is opaque to this module — it just
# composes with whatever address keys the fleet's hosts use. A scope is
# reachability only: which record set answers its names is the DNS
# view's fact, joined here with the `view` ref (see dns-views.nix).
#
# Who terminates ingress for a scope is not a scope fact: it is
# a service (`service.proxy`), the way a thing that forwards is a node. A
# service is proxied on the proxy that serves its scope, overridable
# per service; a scope no proxy serves is reached directly at the
# service's backend. Keeping the proxy out of the context is what lets the
# same scope be served by different boxes (or by none) without rewriting
# the scope.
#
# This module owns the abstract concept; concrete scope names and
# address keys are fleet data (tier 3).
{
  options = { lib, ... }: {
    scopes = lib.mkOption {
      description = ''
        Attribute set of reachability scopes. Services list the
        scopes they participate in via service.scopes.
      '';
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = ''
              Address key (looked up in the `addresses` aspect on a
              host that terminates ingress for this scope). Determines
              the bind interface and the DNS A record value.
            '';
          };
          view = lib.mkOption {
            type = lib.types.str;
            description = ''
              Ref to the dnsViews entry whose record set answers this
              scope's names. Required — every scope names its DNS view;
              reachability and DNS mechanism are separate facts.
            '';
          };
        };
      });
    };
  };

  # The scope→view join must land on a declared view.
  config = { config, ... }: let
    knownViews = builtins.attrNames (config.dnsViews or {});
  in {
    assertions = builtins.attrValues (builtins.mapAttrs (scopeName: s: {
      assertion = builtins.elem s.view knownViews;
      message = "scope '${scopeName}': unknown dnsView '${s.view}' (known: ${builtins.toJSON knownViews})";
    }) (config.scopes or {}));
  };
}
