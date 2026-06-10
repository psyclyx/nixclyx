# Egregore → nginx static sites projection.
#
# A host running nginx for localhost-backend static-content services
# only needs to provide root paths per service entity; the service's
# domain and listen port already live in egregore.
#
# Wire it via:
#
#   psyclyx.nixos.derived.nginx-static.roots = {
#     <service-name> = <derivation or path>;
#     ...
#   };
#
# The projection looks each service entity up, takes its `domain` +
# `backend.local.port`, and emits the matching
# `psyclyx.nixos.services.nginx.staticSites.<domain>` entry.
#
# Hosts can still define manual staticSites entries directly for sites
# that don't have an egregore service entity — the projection only
# populates the entries it knows about.
{config, lib, ...}: let
  cfg = config.psyclyx.nixos.derived.nginx-static;
  eg = config.psyclyx.egregore;

  resolveSite = svcName: root: let
    svcEnt = eg.entities.${svcName} or null;
    domain = svcEnt.attrs.resolvedDomain or null;
    port = svcEnt.service.backend.local.port or null;
  in
    if svcEnt == null || domain == null || port == null then null
    else lib.nameValuePair domain { inherit root port; };

  resolvedSites = builtins.listToAttrs
    (builtins.filter (x: x != null)
      (lib.mapAttrsToList resolveSite cfg.roots));
in {
  options.psyclyx.nixos.derived.nginx-static = {
    roots = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      description = ''
        Map of service entity name → root path. For each entry, the
        projection emits an nginx static-site config using the
        service entity's `domain` + `backend.local.port`.
      '';
    };
  };

  config = lib.mkIf (cfg.roots != {}) {
    psyclyx.nixos.services.nginx.staticSites = resolvedSites;
  };
}
