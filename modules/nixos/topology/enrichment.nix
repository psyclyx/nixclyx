{
  config,
  lib,
  nixclyx,
  ...
}: let
  topo = config.psyclyx.topology;
  enriched = nixclyx.lib.topology lib topo;
  fleet = nixclyx.lib.fleet lib topo;
in {
  options.psyclyx.topology.enriched = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Enriched topology data — derived from psyclyx.topology.";
  };

  options.psyclyx.fleet = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Fleet query library — pure functions over topology data.";
  };

  config = {
    psyclyx.topology.enriched = enriched;
    psyclyx.fleet = fleet;
  };
}
