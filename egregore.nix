# Egregore entry point — declares which types, extensions, and data to load.
#
# The CLI evaluates this file. Your repo provides one of these at its root.
#
# Returns: { lib, modules }
#   lib     — path to the egregore framework
#   modules — list of modules to pass to egregore.eval
#
{
  lib = ./egregore;

  modules = [
    ./egregore/extensions/globals.nix
    ./egregore/types/network.nix
    ./egregore/types/host.nix
    ./egregore/types/routeros.nix
    ./egregore/types/swos.nix
    ./egregore/types/sodola.nix
    ./egregore/types/ilo.nix
    ./egregore/types/unmanaged.nix
    ./egregore/types/ha-group.nix
    ./data/egregore.nix
  ];
}
