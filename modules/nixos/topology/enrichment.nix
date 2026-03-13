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
    description = "Enriched topology data.";
  };

  options.psyclyx.fleet = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Fleet query library.";
  };

  config = {
    psyclyx.topology.enriched = enriched;
    psyclyx.fleet = fleet;
  };
}
