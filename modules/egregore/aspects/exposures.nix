# Exposures — the listeners a node holds (model §6).
#
# An exposure is a reservation: it states where a listener is when the
# listener is active, not when it is active (that is host
# configuration). Each exposure is named; the name gives the exposure
# its identity (an offering refs an exposure by name) and the role says
# which projection reads it (§8.5) — the egregore core reads neither.
#
# This aspect is the one home — ssh, initrd-ssh and the exporter
# exposures live here, declared in data or computed. Exporter exposures
# derive from tags and ha-group membership with per-key `mkDefault` —
# written as data or computed, same structure, read the same way
# (`egregorLib.exposuresOf`).
{
  egregoreAspect = { lib, egregorLib, ... }: {
    options = {
      exposures = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            role = lib.mkOption {
              type = lib.types.str;
              description = ''
                The kind of listener. A projection dispatches on this
                field, not on the name (§8.5).
              '';
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "The port of the listener.";
            };
            scopes = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Names of the scopes from which the listener is reachable
                (§7). A scope is a place, not a segment.
              '';
            };
            identity = lib.mkOption {
              type = lib.types.nullOr egregorLib.refType;
              default = null;
              description = "The key or the certificate of the listener.";
            };
          };
        });
        default = { };
        description = ''
          Named listeners on this node — where they sit when active.
          Declared in data or derived (exporter exposures); a declared
          entry of the same name wins outright over a derived one.
        '';
      };
    };
  };
}
