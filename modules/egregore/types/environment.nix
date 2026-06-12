# Entity type: environment (a logical deployment context).
#
# Environments are where services run: staging, production, etc.
# An environment has a DNS domain for service naming and lives at
# a particular site. The environment knows nothing about what
# services run in it or how they're deployed.
{
  egregoreType = { lib, ... }: {
    name = "environment";
    description = "A logical deployment environment.";

    options = {
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "DNS zone for services in this environment (e.g. stage.psyclyx.net).";
      };
      site = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Site entity name where this environment is hosted.";
      };
      network = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Network entity this environment lives on. Set for envs that
          own a network (e.g. cluster envs whose VMs sit on a dedicated
          VLAN); null for logical-only envs that share a network with
          others. When set, projections like cluster-envs.nix find the
          bridge + access port for VMs whose `environment` field points
          here.
        '';
      };
    };

    attrs = name: entity: top: let
      e = entity.environment;
      netEnt = if e.network != null then top.entities.${e.network} or null else null;
    in {
      domain = e.domain;
      site = e.site;
      network = e.network;
      # Convenience: zone of the network this env owns. Null when the
      # env has no network or the network has no zone.
      zone =
        if netEnt != null then (netEnt.network.zone or "") else "";
      label = name;
    };

    assertions = name: entity: top: let
      e = entity.environment;
    in
      lib.optional (e.site != null) {
        assertion = top.entities ? ${e.site} && top.entities.${e.site}.type == "site";
        message = "environment '${name}' references site '${e.site}' which is not a site entity";
      }
      ++ lib.optional (e.network != null) {
        assertion = top.entities ? ${e.network} && top.entities.${e.network}.type == "network";
        message = "environment '${name}' references network '${e.network}' which is not a network entity";
      };
  };
}
