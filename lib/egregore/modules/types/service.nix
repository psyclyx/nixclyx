# Entity type: service — a named offering, and how it is presented.
#
# Split into two concerns that change for different reasons:
#
#   intrinsic  protocol, backend, scopes
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
  egregoreType = { lib, egregorLib, ... }: {
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
              type = lib.types.nullOr egregorLib.exposureRefType;
              default = null;
              description = ''
                Backend on an exposure of a named node — the offering
                runs on the exposure (model §5). The ref names the node
                (`target`) and the exposure on it (`exposure`); the
                exposure owns the port and the scopes, so moving the
                backend is an edit to this reference (or to the
                exposure).
              '';
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
          routes by name for the scopes in `scopes`, running on
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
      scopes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          Reachability scopes (named in the top-level `scopes` set)
          where this service is reachable. Required — every service
          must enumerate the scopes it participates in.
        '';
      };
      ingress = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Per-scope proxy override, keyed by scope name: the
          `service.proxy` that fronts this service in that scope.
          Scopes not listed here use the unique proxy serving the
          scope; if none serves it, the service is direct there.
        '';
      };
    };

    deriveOptions = {
      resolvedDomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Resolved FQDN — the explicit domain, or <name>.<env.domain>. Null when not presented.";
      };
      backendType = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Which backend shape this offering has: \"ha\", \"host\", \"local\", or \"none\".";
      };
      resolvedAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Address the offering is reached at: the HA VIP, the backend
          node's address at its exposure's address key, or 127.0.0.1 for
          a local backend. Null when unresolvable.
        '';
      };
      resolvedPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Resolved port of the offering (from the exposure, HA group, or local backend).";
      };
      effectiveIngress = lib.mkOption {
        type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
        default = { };
        description = ''
          Per-scope ingress host actually fronting this service, keyed
          by scope name. Null value = the service is direct in that
          scope (no proxy serves it).
        '';
      };
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The offering's URL (its presentation: https FQDN, or direct http address:port). Null when neither applies.";
      };
      label = lib.mkOption { type = lib.types.str; };
      protocol = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Offering protocol (\"http\" or \"tcp\"; mirrors `service.protocol`).";
      };
      websockets = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Websocket upgrade support (mirrors `service.websockets`).";
      };
      streaming = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Long-lived HTTP responses (mirrors `service.streaming`).";
      };
    };

    derive = name: entity: top: let
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

      # Backend on a named exposure: the offering runs on the exposure
      # (model §5) — the ref names the node and the exposure on it. The
      # exposure owns the port and the scopes; the resolved address is
      # the node's address at the address key of the exposure's first
      # scope (scopes map to address keys, §7 — a network-named scope
      # falls back to the scope name itself), so the offering moves with
      # the graph instead of carrying a literal IP.
      hostExposure =
        if backendType == "host"
        then (top.entities.${s.backend.host.target}.exposures.${s.backend.host.exposure} or null)
        else null;
      hostScope =
        if hostExposure != null && hostExposure.scopes != []
        then builtins.head hostExposure.scopes
        else null;
      hostAddrKey =
        if hostScope != null
        then (top.scopes.${hostScope} or {}).address or hostScope
        else null;
      hostBackendAddr =
        if hostAddrKey != null
        then (top.entities.${s.backend.host.target}.addresses.${hostAddrKey} or {}).ipv4 or null
        else null;

      # Resolved address and port
      resolvedAddress =
        if backendType == "ha" && haGroup != null then haGroup.ha-group.vip.ipv4
        else if backendType == "host" then hostBackendAddr
        else if backendType == "local" then "127.0.0.1"
        else null;
      resolvedPort =
        if backendType == "ha" && haGroup != null
        # Read the derived `services` aspect (resolved with defaultServiceMeta
        # merged in) rather than ha-group.services (raw entity values, where
        # ports default to null per the per-service-overrides-only convention).
        then haGroup.services.${haSvcName}.port
        else if backendType == "host" then (if hostExposure != null then hostExposure.port else null)
        else if backendType == "local" then s.backend.local.port
        else null;

      # The proxy fronting a scope is a *service* (`service.proxy`)
      # that serves it — not a host role. A per-service `ingress`
      # override names a proxy directly. A scope no proxy serves, or
      # one several claim, is direct for this service: the projection
      # emits nothing.
      proxyServing = sc: let
        claimants = builtins.filter
          (n: let e = top.entities.${n}; in
            e.type == "service" && (e.service.proxy or null) != null
            && builtins.elem sc e.service.scopes)
          (builtins.attrNames top.entities);
      in if builtins.length claimants == 1 then builtins.head claimants else null;
      proxyHostOf = p: if p == null then null else (top.entities.${p}.service.proxy.host or null);
      effectiveIngress = builtins.listToAttrs (map (sc: let
        override = s.ingress.${sc} or null;
        proxy = if override != null then override else proxyServing sc;
      in lib.nameValuePair sc (proxyHostOf proxy)) s.scopes);
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
      knownScopes = builtins.attrNames (top.scopes or {});
      unknownScopes = builtins.filter (a: !(builtins.elem a knownScopes)) s.scopes;
      overrideKeys = builtins.attrNames s.ingress;
      extraIngressKeys = builtins.filter (k: !(builtins.elem k s.scopes)) overrideKeys;
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
      assertion = top.entities ? ${s.backend.host.target} && top.entities.${s.backend.host.target}.type == "host";
      message = "service '${name}': backend.host.target '${s.backend.host.target}' is not a host entity";
    }
    ++ lib.optional (s.backend.host != null && top.entities ? ${s.backend.host.target}) {
      assertion = (top.entities.${s.backend.host.target}.exposures or {}) ? ${s.backend.host.exposure};
      message = "service '${name}': backend.host.exposure '${s.backend.host.exposure}' is not an exposure on '${s.backend.host.target}'";
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
        assertion = unknownScopes == [];
        message = "service '${name}': unknown scopes ${builtins.toJSON unknownScopes} (known: ${builtins.toJSON knownScopes})";
      }
      {
        assertion = extraIngressKeys == [];
        message = "service '${name}': ingress override keys ${builtins.toJSON extraIngressKeys} not in declared scopes ${builtins.toJSON s.scopes}";
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
