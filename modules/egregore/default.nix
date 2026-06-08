# Egregore modules — reusable entity types and extensions.
#
# Types define the schema, attrs, and verbs for each entity kind.
# Extensions add cross-cutting options (globals, audiences, etc.).
#
# These are egregore module specs — they go through the shared
# spec compiler (`nixclyx/lib/modules.nix`) with the egregore-type
# interceptor in the chain. Consumers compose with their own data
# specs and feed the lot to egregore.eval.
let
  fs = import ../../lib/fs.nix;
in {
  typeSpecs = map builtins.import (fs.collectModules ./types);
  extensionSpecs = map builtins.import (fs.collectModules ./extensions);
}
