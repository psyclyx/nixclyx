# Entity type: service (a named, reachable endpoint).
{ lib, egregorLib, config, ... }:
egregorLib.mkType {
  name = "service";
  topConfig = config;
  description = "A named, reachable endpoint (HTTP or TCP).";

  options = {
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicit FQDN. Mutually exclusive with environment.";
    };
    environment = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Environment entity name. Domain becomes <service-name>.<env.domain>.";
    };
    protocol = lib.mkOption {
      type = lib.types.enum ["http" "tcp"];
      default = "http";
    };
    backend = lib.mkOption {
      type = lib.types.submodule {
        options = {
          ha = lib.mkOption {
            type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
            default = null;
            description = "HA group backend. { <group> = \"<service>\"; }";
          };
          host = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                address = lib.mkOption { type = lib.types.str; };
                port = lib.mkOption { type = lib.types.int; };
              };
            });
            default = null;
            description = "Fixed host:port backend.";
          };
          local = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                port = lib.mkOption { type = lib.types.int; };
              };
            });
            default = null;
            description = "Localhost backend on the ingress host.";
          };
        };
      };
      default = {};
    };
    websockets = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    label = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Human-readable label for links pages.";
    };
    check = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Health check path (HTTP services only).";
    };
  };

  attrs = name: entity: top: let
    s = entity.service;

    # Domain resolution
    env = if s.environment != null
      then top.entities.${s.environment} or null
      else null;
    resolvedDomain =
      if s.domain != null then s.domain
      else if env != null then "${name}.${env.environment.domain}"
      else null;

    # Backend discrimination (like switch-port.nix portType)
    backendType =
      if s.backend.ha != null then "ha"
      else if s.backend.host != null then "host"
      else if s.backend.local != null then "local"
      else "none";

    # HA backend resolution
    haGroupName =
      if s.backend.ha != null
      then builtins.head (builtins.attrNames s.backend.ha)
      else null;
    haSvcName =
      if s.backend.ha != null
      then s.backend.ha.${haGroupName}
      else null;
    haGroup =
      if haGroupName != null && top.entities ? ${haGroupName}
      then top.entities.${haGroupName}
      else null;

    # Resolved address and port
    resolvedAddress =
      if backendType == "ha" && haGroup != null then haGroup.ha-group.vip.ipv4
      else if backendType == "host" then s.backend.host.address
      else if backendType == "local" then "127.0.0.1"
      else null;
    resolvedPort =
      if backendType == "ha" && haGroup != null
      then haGroup.ha-group.services.${haSvcName}.port
      else if backendType == "host" then s.backend.host.port
      else if backendType == "local" then s.backend.local.port
      else null;
  in {
    inherit resolvedDomain backendType resolvedAddress resolvedPort;
    url = if s.protocol == "http" && resolvedDomain != null
      then "https://${resolvedDomain}"
      else null;
    label = if s.label != null then s.label else name;
    protocol = s.protocol;
    websockets = s.websockets;
  };

  assertions = name: entity: top: let
    s = entity.service;
    backendCount =
      (if s.backend.ha != null then 1 else 0)
      + (if s.backend.host != null then 1 else 0)
      + (if s.backend.local != null then 1 else 0);
    haGroupName =
      if s.backend.ha != null
      then builtins.head (builtins.attrNames s.backend.ha)
      else null;
    haSvcName =
      if s.backend.ha != null
      then s.backend.ha.${haGroupName}
      else null;
  in [
    {
      assertion = backendCount == 1;
      message = "service '${name}': exactly one backend required (ha, host, or local), got ${toString backendCount}";
    }
    {
      assertion = s.domain != null || s.environment != null;
      message = "service '${name}': must set either 'domain' or 'environment'";
    }
    {
      assertion = !(s.domain != null && s.environment != null);
      message = "service '${name}': cannot set both 'domain' and 'environment'";
    }
  ]
  ++ lib.optional (s.environment != null) {
    assertion = top.entities ? ${s.environment} && top.entities.${s.environment}.type == "environment";
    message = "service '${name}': environment '${s.environment}' is not an environment entity";
  }
  ++ lib.optional (s.backend.ha != null) {
    assertion = builtins.length (builtins.attrNames s.backend.ha) == 1;
    message = "service '${name}': backend.ha must have exactly one entry";
  }
  ++ lib.optional (haGroupName != null) {
    assertion = top.entities ? ${haGroupName} && top.entities.${haGroupName}.type == "ha-group";
    message = "service '${name}': backend.ha references '${haGroupName}' which is not an ha-group entity";
  }
  ++ lib.optional (haGroupName != null && top.entities ? ${haGroupName}) {
    assertion = top.entities.${haGroupName}.ha-group.services ? ${haSvcName};
    message = "service '${name}': ha-group '${haGroupName}' has no service '${haSvcName}'";
  };
}
