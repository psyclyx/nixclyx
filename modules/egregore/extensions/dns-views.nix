# DNS views — named record sets a resolver answers from.
#
# A DNS view is a primitive abstract concept: a record set. Two views
# give different records for one name (split-horizon DNS). Its one
# intrinsic fact is the record-set mechanism its names are answered
# from; a projection dispatches on that fact to pick where records go,
# never on a scope's address key.
#
# A view does not know who reaches what: reachability is the scope's
# fact. A scope joins a view with a ref (`scopes.<n>.view`); the scope
# maps to an address key, the view maps to a record set. Joining them
# with a ref is what lets one name resolve differently per view while
# each concept stays a single fact.
#
# This module owns the abstract concept; concrete view names and
# mechanisms are fleet data (tier 3).
{
  options = { lib, ... }: {
    dnsViews = lib.mkOption {
      description = ''
        Attribute set of DNS views. A scope names the view its
        services' names are answered from via `scopes.<n>.view`.
      '';
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          records = lib.mkOption {
            type = lib.types.enum [ "authoritative" "localzone" ];
            description = ''
              Which record-set mechanism this view's names are answered
              from: the authoritative zones, or resolver-localzone
              records.
            '';
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };
      });
    };
  };
}
