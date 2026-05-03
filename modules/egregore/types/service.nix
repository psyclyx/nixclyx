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
    streaming = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Long-lived HTTP responses (SSE, long polling). Disables
        compression for the backend and bumps `timeout server` so idle
        streams aren't killed.
      '';
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
    audiences = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Reachability contexts (named in globals.audiences) where this
        service is reachable. Required — every service must enumerate
        the audiences it participates in.
      '';
    };
    ingress = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Per-audience ingress host override, keyed by audience name.
        Audiences not listed here use the audience's defaultIngress.
      '';
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
      # Read attrs.services (resolved with defaultServiceMeta merged in)
      # rather than ha-group.services (raw entity values, where ports
      # default to null per the per-service-overrides-only convention).
      then haGroup.attrs.services.${haSvcName}.port
      else if backendType == "host" then s.backend.host.port
      else if backendType == "local" then s.backend.local.port
      else null;

    # Resolve audience → ingress host. Per-service ingress override wins,
    # otherwise fall back to the audience's defaultIngress.
    audienceDefs = top.audiences or {};
    effectiveIngress = builtins.listToAttrs (map (a: let
      override = s.ingress.${a} or null;
      audience = audienceDefs.${a} or null;
      host =
        if override != null then override
        else if audience != null then audience.defaultIngress
        else null;
    in lib.nameValuePair a host) s.audiences);
  in {
    inherit resolvedDomain backendType resolvedAddress resolvedPort;
    inherit effectiveIngress;
    url = if s.protocol == "http" && resolvedDomain != null
      then "https://${resolvedDomain}"
      else null;
    label = if s.label != null then s.label else name;
    protocol = s.protocol;
    websockets = s.websockets;
    streaming = s.streaming;
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
    knownAudiences = builtins.attrNames (top.audiences or {});
    unknownAudiences = builtins.filter (a: !(builtins.elem a knownAudiences)) s.audiences;
    overrideKeys = builtins.attrNames s.ingress;
    extraIngressKeys = builtins.filter (k: !(builtins.elem k s.audiences)) overrideKeys;
    invalidIngressHosts = lib.filter
      (h: !(top.entities ? ${h} && top.entities.${h}.type == "host"))
      (builtins.attrValues s.ingress);
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
  }
  ++ [
    {
      assertion = unknownAudiences == [];
      message = "service '${name}': unknown audiences ${builtins.toJSON unknownAudiences} (known: ${builtins.toJSON knownAudiences})";
    }
    {
      assertion = extraIngressKeys == [];
      message = "service '${name}': ingress override keys ${builtins.toJSON extraIngressKeys} not in declared audiences ${builtins.toJSON s.audiences}";
    }
    {
      assertion = invalidIngressHosts == [];
      message = "service '${name}': ingress override targets ${builtins.toJSON invalidIngressHosts} are not host entities";
    }
  ];
}
