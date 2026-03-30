# Egregore entry point — declares which types, extensions, and data to load.
#
# The CLI evaluates this file. Your repo provides one of these at its root.
#
# Returns: { lib, modules }
#   lib     — path to the egregore framework
#   modules — list of modules to pass to egregore.eval
#
let
  mods = import ./modules/egregore;
in {
  lib = ./egregore;

  modules =
    mods.types
    ++ mods.extensions
    ++ [ ./data/egregore.nix ];
}
