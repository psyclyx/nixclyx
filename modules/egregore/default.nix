# Egregore modules — reusable entity types and extensions.
#
# Types define the schema, attrs, and verbs for each entity kind.
# Extensions add cross-cutting options (globals, etc.).
#
# These are egregore modules (for egregore.eval), not NixOS modules.
{
  types = [
    ./types/network.nix
    ./types/host.nix
    ./types/routeros.nix
    ./types/swos.nix
    ./types/sodola.nix
    ./types/ilo.nix
    ./types/unmanaged.nix
    ./types/ha-group.nix
  ];

  extensions = [
    ./extensions/globals.nix
  ];
}
