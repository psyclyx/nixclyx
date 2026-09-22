# Entity type: service — a named offering, and how it is presented.
#
# Split into two concerns that change for different reasons:
#
#   intrinsic  protocol, backend, audiences
#              what it offers, where it runs, who can reach it
#   presentation  domain/environment, ingress, websockets, streaming, check
#              how it is named and proxied in each reachability context
#
# A service need not be presented: `tang` is an HTTP offering reached
# directly at its backend address, with no FQDN and no ingress. The
# presentation fields are then simply absent, and the ingress projection
# (which keys on a resolved domain and an ingress host) ignores it.
#
# `kind` is the one deliberate exception (see its definition): a label,
# not a mechanism.
{
  egregoreType = { lib, ... }: {
    name = "service";
    description = "A named, reachable offering (HTTP or raw TCP).";

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

      # COHESION EXCEPTION: a one-word label ("tang", "kdc", ...) so a
      # service can be recognised by kind without fragmenting into a
      # type per vendor. This is a label ONLY — the mechanism behind a
      # kind (tang's keys, a KDC's database) is host config, never a
      # block here. If this grows past a label, it is no longer an
      # exception and the kind gets a proper noun.
      kind = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional kind label. Fleet fact role, not a mechanism carrier.";
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
                  host = lib.mkOption {
                    type = lib.types.str;
                    description = "Backend host entity name.";
                  };
                  network = lib.mkOption {
                    type = lib.types.str;
                    description = ''
                      Network entity whose address on `host` the backend
                      is reached at. Derived, not a literal IP — moving
                      the backend is an edit to this reference.
                    '';
                  };
                  port = lib.mkOption { type = lib.types.port; };
                };
              });
              default = null;
              description = "Backend on a named host, at its address on a network.";
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
      proxy = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options.host = lib.mkOption {
            type = lib.types.str;
            description = "Host entity that runs the proxy.";
          };
        });
        default = null;
        description = ''
          Set when this service is a reverse proxy: it terminates TLS and
          routes by name for the audiences in `audiences`, running on
          `host`. Its routing table is derived — from the presentation of
          the services it fronts — so it is not declared here. A proxy is
          a service (it offers HTTP/HTTPS); this block is its placement.
        '';
      };
      reach = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Networks whose clients may reach this service directly, beyond
          its backend's own network. For a direct service (no proxy) that
          needs an explicit ACL — e.g. tang, reached from a second VLAN.
        '';
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
          Per-audience proxy override, keyed by audience name: the
          `service.proxy` that fronts this service in that audience.
          Audiences not listed here use the unique proxy serving the
          audience; if none serves it, the service is direct there.
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

      # Backend on a named host: its address on the chosen network is the
      # resolved address, so the offering moves with the graph instead of
      # carrying a literal IP.
      hostBackendAddr =
        if backendType == "host"
        then (top.entities.${s.backend.host.host}.attrs.addresses.${s.backend.host.network} or {}).ipv4 or null
        else null;

      # Resolved address and port
      resolvedAddress =
        if backendType == "ha" && haGroup != null then haGroup.ha-group.vip.ipv4
        else if backendType == "host" then hostBackendAddr
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

      # The proxy fronting an audience is a *service* (`service.proxy`)
      # that serves it — not a host role. A per-service `ingress`
      # override names a proxy directly. An audience no proxy serves, or
      # one several claim, is direct for this service: the projection
      # emits nothing.
      proxyServing = a: let
        claimants = builtins.filter
          (n: let e = top.entities.${n}; in
            e.type == "service" && (e.service.proxy or null) != null
            && builtins.elem a e.service.audiences)
          (builtins.attrNames top.entities);
      in if builtins.length claimants == 1 then builtins.head claimants else null;
      proxyHostOf = p: if p == null then null else (top.entities.${p}.service.proxy.host or null);
      effectiveIngress = builtins.listToAttrs (map (a: let
        override = s.ingress.${a} or null;
        proxy = if override != null then override else proxyServing a;
      in lib.nameValuePair a (proxyHostOf proxy)) s.audiences);
    in {
      inherit resolvedDomain backendType resolvedAddress resolvedPort;
      inherit effectiveIngress;
      # A service's URL is its presentation: the FQDN when it has one,
      # otherwise the address it is reached at directly (e.g. tang).
      url =
        if s.protocol == "http" && resolvedDomain != null then "https://${resolvedDomain}"
        else if s.protocol == "http" && resolvedAddress != null && resolvedPort != null
          then "http://${resolvedAddress}:${toString resolvedPort}"
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
      invalidIngressProxies = lib.filter
        (p: !(top.entities ? ${p} && (top.entities.${p}.service.proxy or null) != null))
        (builtins.attrValues s.ingress);
      dnsAuthRef = entity.refs.dnsAuthority or null;
    in [
      {
        assertion = backendCount == 1 || s.proxy != null;
        message = "service '${name}': exactly one backend required (ha, host, or local), got ${toString backendCount}";
      }
      {
        assertion = !(s.domain != null && s.environment != null);
        message = "service '${name}': cannot set both 'domain' and 'environment'";
      }
    ]
    ++ lib.optional (s.backend.host != null) {
      assertion = top.entities ? ${s.backend.host.host} && top.entities.${s.backend.host.host}.type == "host";
      message = "service '${name}': backend.host.host '${s.backend.host.host}' is not a host entity";
    }
    ++ lib.optional (s.backend.host != null) {
      assertion = top.entities ? ${s.backend.host.network} && top.entities.${s.backend.host.network}.type == "network";
      message = "service '${name}': backend.host.network '${s.backend.host.network}' is not a network entity";
    }
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
        assertion = invalidIngressProxies == [];
        message = "service '${name}': ingress override targets ${builtins.toJSON invalidIngressProxies} are not proxy services";
      }
    ]
    ++ lib.optional (dnsAuthRef != null) {
      assertion = top.entities ? ${dnsAuthRef} && top.entities.${dnsAuthRef}.type == "host";
      message = "service '${name}': refs.dnsAuthority → '${dnsAuthRef}' must be a host entity";
    };
  };
}
