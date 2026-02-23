{
  config,
  lib,
  nixclyx,
  ...
}: let
  topo = config.psyclyx.topology;
  enriched = nixclyx.lib.topology lib topo;
in {
  options.psyclyx.topology.enriched = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Enriched topology data — derived from psyclyx.topology.";
  };

  config.psyclyx.topology.enriched = enriched;
}
