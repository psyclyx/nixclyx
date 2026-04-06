# Entity type: environment (a logical deployment context).
#
# Environments are where services run: staging, production, etc.
# An environment has a DNS domain for service naming and lives at
# a particular site. The environment knows nothing about what
# services run in it or how they're deployed.
{ lib, egregorLib, config, ... }:
egregorLib.mkType {
  name = "environment";
  topConfig = config;
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
  };

  attrs = name: entity: _top: let
    e = entity.environment;
  in {
    domain = e.domain;
    site = e.site;
    label = name;
  };

  assertions = name: entity: top: let
    e = entity.environment;
  in
    lib.optional (e.site != null) {
      assertion = top.entities ? ${e.site} && top.entities.${e.site}.type == "site";
      message = "environment '${name}' references site '${e.site}' which is not a site entity";
    };
}
