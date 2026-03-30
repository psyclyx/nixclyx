# Egregore modules — reusable entity types and extensions.
#
# Types define the schema, attrs, and verbs for each entity kind.
# Extensions add cross-cutting options (globals, etc.).
#
# These are egregore modules (for egregore.eval), not NixOS modules.
# Type modules use mkType which manages its own options/config structure,
# so they stay as plain modules rather than specs.
let
  fs = import ../../lib/fs.nix;
in {
  types = fs.collectModules ./types;
  extensions = fs.collectModules ./extensions;
}
