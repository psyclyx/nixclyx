# Egregore modules — reusable entity types and extensions.
#
# Types define the schema, attrs, and verbs for each entity kind.
# Extensions add cross-cutting options (globals, audiences, etc.).
#
# These are egregore module specs — they go through the shared
# spec compiler (`nixclyx/lib/spec`) with the egregore-type
# interceptor in the chain. Consumers compose with their own data
# specs and feed the lot to egregore.eval.
let
  fs = import ../../lib/fs.nix;
  # The generic vocabulary (site, network, host, service, route) lives with
  # the egregore library; the fleet's own and vendor nouns stay here.
  genericTypeSpecs = map builtins.import (fs.collectModules ../../lib/egregore/modules/types);
  fleetTypeSpecs = map builtins.import (fs.collectModules ./types);
in {
  typeSpecs = genericTypeSpecs ++ fleetTypeSpecs;
  extensionSpecs = map builtins.import (fs.collectModules ./extensions);
}
