# Ingress projection — scope-driven, dispatching on the DNS view.
#
# For every (service, scope) pair, the projection determines who runs
# ingress (service.effectiveIngress) and emits, on that host:
#
#   - one HAProxy backend per service (shared across scopes)
#   - one HAProxy frontend per scope, bound on this host's address
#     for that scope's address key
#   - ACME cert config when this host can issue locally (its
#     dnsAuthority covers the cert's zone). Hosts that need a cert they
#     can't issue locally fetch it via the cert distribution module.
#   - resolver localZones records for scopes whose view is answered from
#     localzone records, emitted on the resolver host (the scope's
#     address key resolves to a network entity whose refs.dns names the
#     resolver).
#   - authoritative zone A/AAAA records for scopes whose view is
#     answered from authoritative records, on hosts with dnsAuthority
#     for the matching zone.
#
# The view decides the record set; the scope's address key gives the
# record value. DNS resolution targets the *ingress host*'s address on
# the scope's address key — so road warriors hitting tleilax's resolver
# for light.psyclyx.net get back iyr's vpn IP, not tleilax's, and
# there's no hairpin.
{ config, lib, pkgs, ... }: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  # `me` is null on hosts that aren't first-class egregore entities.
  # All usages below sit inside `mkIf`-guarded sections that are inert
  # on those hosts, so the null never propagates.
  me = eg.entities.${hostname} or null;

  services = lib.filterAttrs (_: e: e.type == "service") eg.entities;
  # Presentation requires a resolved domain: a service reached directly
  # (no FQDN, no ingress — e.g. tang) is not the ingress projection's
  # business. It is skipped here, not mangled into a null-domain record.
  presented = lib.filterAttrs (_: e: e.resolvedDomain != null) services;
  httpServices = lib.filterAttrs (_: e: e.service.protocol == "http") presented;
  tcpServices = lib.filterAttrs (_: e: e.service.protocol == "tcp") presented;

  scopes = eg.scopes;
  envEntities = lib.filterAttrs
    (_: e: e.type == "environment" && e.environment.domain != null)
    eg.entities;
  envDomains = lib.mapAttrsToList (_: e: e.environment.domain) envEntities;

  # --- Tuple expansion ---

  mkTuples = svcs: lib.concatLists (lib.mapAttrsToList (svcName: e:
    lib.mapAttrsToList (scopeName: ingHost: let
      viewName = scopes.${scopeName}.view;
    in {
      inherit svcName scopeName ingHost viewName;
      svc = e;
      scopeAddress = scopes.${scopeName}.address;
      view = eg.dnsViews.${viewName};
    }) e.effectiveIngress
  ) svcs);

  httpTuples = mkTuples httpServices;
  tcpTuples = mkTuples tcpServices;

  myIngressTuples = lib.filter (t: t.ingHost == hostname) httpTuples;
  myTuplesByScope = builtins.groupBy (t: t.scopeName) myIngressTuples;

  # --- Cert resolution ---

  internalDomain = eg.domains.internal;

  # Returns { name; extraDomainNames; } describing the cert that covers
  # `domain`. Env wildcards are checked BEFORE the internal wildcard
  # because env zones are subdomains of the internal zone
  # (stage.psyclyx.net under psyclyx.net) — *.psyclyx.net does not
  # cover *.stage.psyclyx.net (wildcards are single-label).
  certFor = domain: let
    envD = lib.findFirst
      (d: d == domain || lib.hasSuffix ".${d}" domain)
      null
      envDomains;
  in
    if envD != null then
      { name = envD; extraDomainNames = ["*.${envD}"]; }
    else if internalDomain != "" && lib.hasSuffix ".${internalDomain}" domain then
      { name = internalDomain; extraDomainNames = ["*.${internalDomain}"]; }
    else
      { name = domain; extraDomainNames = []; };

  # A host can issue an ACME cert for `domain` via DNS-01 if any zone in
  # its dnsAuthority is `domain` itself or a parent of it (TSIG access
  # to the parent suffices for _acme-challenge.<domain> updates).
  # Union of a host's intrinsic dnsAuthority and any apex zones
  # contributed by services that ref this host via refs.dnsAuthority.
  effectiveDnsAuthority = h: let
    intrinsic = h.dnsAuthority or [];
    sources = h.refsIn.dnsAuthority or [];
    contributed = lib.concatMap (n: let
      e = eg.entities.${n} or null;
    in lib.optional (e != null && e.type == "service" && e.resolvedDomain != null)
      e.resolvedDomain) sources;
  in lib.unique (intrinsic ++ contributed);

  hostHasAuthority = hostName: domain: let
    h = eg.entities.${hostName} or null;
    zones = if h != null && h.type == "host" then effectiveDnsAuthority h else [];
  in builtins.any (z: z == domain || lib.hasSuffix ".${z}" domain) zones;

  iCanIssue = domain: hostHasAuthority hostname domain;

  # Resolved cert path (haproxy bind directive looks here).
  certPath = name: "/var/lib/acme/${name}/full.pem";

  authCfg = config.psyclyx.nixos.network.dns.authoritative;

  mkDns01Credentials = {
    "RFC2136_NAMESERVER_FILE" = pkgs.writeText "rfc2136-ns" "${builtins.head authCfg.interfaces}:${toString authCfg.port}";
    "RFC2136_TSIG_ALGORITHM_FILE" = pkgs.writeText "rfc2136-algo" "hmac-sha256.";
    "RFC2136_TSIG_KEY_FILE" = pkgs.writeText "rfc2136-keyname" authCfg.tsigKeyName;
    "RFC2136_TSIG_SECRET_FILE" = authCfg.tsigSecretFile;
  };

  # Unique cert specs needed for my ingress (one per cert.name).
  myCertSpecs = let
    perTuple = map (t: certFor t.svc.resolvedDomain) myIngressTuples;
    byName = builtins.groupBy (c: c.name) perTuple;
  in lib.mapAttrs (_: cs: builtins.head cs) byName;

  # Certs I can issue locally — emitted as security.acme entries.
  locallyIssuedCerts = lib.filterAttrs (_: c: iCanIssue c.name) myCertSpecs;

  # --- HAProxy backend (one per service) ---

  mkBackend = svcName: e: let
    a = e;
    s = e.service;
    # A `local` backend is localhost on this proxy host unless the host
    # config names another host-local address (e.g. a netns veth).
    localOverride = config.psyclyx.nixos.services.ingress.localBackendAddress.${svcName} or null;
    backendAddr =
      if a.backendType == "local" && localOverride != null then localOverride
      else a.resolvedAddress;
    opts = lib.concatStringsSep "\n" (
      lib.optional s.websockets "    option http-server-close"
      ++ lib.optionals s.streaming [
        "    timeout server 1h"
        "    compression algo identity"
      ]
      ++ lib.optionals (s.check != null) [
        "    option httpchk"
        "    http-check send meth GET uri ${s.check} ver HTTP/1.1 hdr Host localhost"
        "    http-check expect status 200"
      ]
    );
  in ''

    backend bk_svc_${svcName}
      mode http
  '' + lib.optionalString (opts != "") (opts + "\n")
     + "    server srv1 ${backendAddr}:${toString a.resolvedPort} check inter 10s\n";

  myBackendSvcs = lib.unique (map (t: t.svcName) myIngressTuples);
  backends = lib.concatStringsSep "" (map
    (n: mkBackend n httpServices.${n})
    myBackendSvcs);

  # --- HAProxy frontend (one per scope) ---

  mkFrontend = scopeName: tuples: let
    bind = me.addresses.${scopes.${scopeName}.address}.ipv4;
    certs = lib.unique (map (t: certPath (certFor t.svc.resolvedDomain).name) tuples);
    crtArgs = lib.concatMapStringsSep " " (p: "crt ${p}") certs;
    acls = map
      (t: "    acl host_${t.svcName} hdr(host) -i ${t.svc.resolvedDomain}")
      tuples;
    useBackends = map
      (t: "    use_backend bk_svc_${t.svcName} if host_${t.svcName}")
      tuples;
  in ''

    frontend ft_https_${scopeName}
      bind ${bind}:443 ssl ${crtArgs} strict-sni
      mode http
      option forwardfor
      http-request set-header X-Forwarded-Proto https
  '' + lib.concatStringsSep "\n" acls + "\n"
     + lib.concatStringsSep "\n" useBackends + ''


    frontend ft_http_${scopeName}
      bind ${bind}:80
      mode http
      redirect scheme https code 301
  '';

  frontends = lib.concatStringsSep ""
    (lib.mapAttrsToList mkFrontend myTuplesByScope);

  haproxyConfig = ''
    global
      log stdout local0
      maxconn 4096
      stats socket /run/haproxy/admin.sock mode 660 level admin

    defaults
      log global
      option dontlognull
      timeout connect 5s
      timeout client 1h
      timeout server 1m
      retries 3
      compression algo gzip
      compression type text/html text/plain text/css text/javascript application/javascript application/json application/xml application/xhtml+xml image/svg+xml
  '' + frontends + backends;

  # --- DNS records ---

  # Ingress host's bind address for a scope's address key — what DNS
  # records for that (scope, service) pair point at.
  ingressBindAddr = scopeAddress: ingHost: let
    addr = (eg.entities.${ingHost}.addresses.${scopeAddress} or null);
  in if addr != null then addr.ipv4 else null;

  # Resolver localzone records: emitted on the resolver host for each
  # scope whose view is answered from localzone records. The view picks
  # the record set; the resolver lookup (the scope's address key
  # resolves to a network entity served by this host's resolver) decides
  # where the resolver emits. Pulls all (service, scope) tuples,
  # including TCP services (which use the HA VIP directly via
  # service.resolvedAddress, not an ingress address).
  resolverLocalZoneRecords = let
    localzoneView = t: t.view.records == "localzone";
    isResolverFor = scopeAddress: let
      net = eg.entities.${scopeAddress} or null;
    in net != null && net.type == "network" && (net.dnsRef or null) == hostname;

    httpRecs = lib.concatMap (t:
      lib.optional (localzoneView t && isResolverFor t.scopeAddress)
        "${t.svc.resolvedDomain}. IN A ${ingressBindAddr t.scopeAddress t.ingHost}"
    ) httpTuples;

    tcpRecs = lib.concatMap (t: let
      a = t.svc;
    in
      lib.optional (localzoneView t
                    && isResolverFor t.scopeAddress
                    && a.resolvedAddress != null)
        "${a.resolvedDomain}. IN A ${a.resolvedAddress}"
    ) tcpTuples;
  in lib.unique (httpRecs ++ tcpRecs);

  # Authoritative zone records: tuples whose view is answered from
  # authoritative records — the view dispatches, not the scope's
  # address key.
  publicTuples = lib.filter (t: t.view.records == "authoritative") httpTuples;

  # Authoritative public-zone records: emitted on hosts whose
  # dnsAuthority covers the matching zone, for services in a scope
  # whose view is answered from authoritative records.
  authoritativeZoneRecords = let
    myZones = if me != null then effectiveDnsAuthority me else [];

    # Longest-suffix match from this host's dnsAuthority. Returns the
    # most specific zone covering `domain`, or null if none does.
    zoneFor = domain: lib.foldl' (best: z:
      if (z == domain || lib.hasSuffix ".${z}" domain)
         && (best == null || lib.stringLength z > lib.stringLength best)
      then z else best
    ) null myZones;

    perTuple = lib.concatMap (t: let
      domain = t.svc.resolvedDomain;
      zone = zoneFor domain;
      ingEntity = eg.entities.${t.ingHost};
      addr = ingEntity.addresses.${t.scopeAddress} or { ipv4 = null; ipv6 = null; };
      ipv4 = addr.ipv4 or null;
      ipv6 = addr.ipv6 or null;
      sub = if zone == domain then "@" else lib.removeSuffix ".${zone}" domain;
    in
      lib.optional (zone != null && ipv4 != null) {
        inherit zone sub ipv4 ipv6;
      }
    ) publicTuples;

    byZone = builtins.groupBy (r: r.zone) perTuple;
  in lib.mapAttrs (_: rs:
    lib.concatMapStringsSep "\n" (r:
      "${r.sub} IN A     ${r.ipv4}"
      + (if r.ipv6 != null then "\n${r.sub} IN AAAA  ${r.ipv6}" else "")
    ) rs
  ) byZone;
in {
  config = lib.mkMerge [
    # --- Ingress side: HAProxy + ACME + firewall ---
    (lib.mkIf (myIngressTuples != []) {
      services.haproxy = {
        enable = true;
        config = haproxyConfig;
      };

      systemd.services.haproxy = {
        after = ["network-online.target" "acme-selfsigned-certificates.target"];
        wants = ["network-online.target"];
      };

      users.users.haproxy.extraGroups = ["acme"];

      security.acme = lib.mkIf (locallyIssuedCerts != {}) {
        acceptTerms = true;
        defaults.email = config.psyclyx.nixos.services.nginx.acme.email;
        certs = lib.mapAttrs (_: c: {
          domain = c.name;
          extraDomainNames = c.extraDomainNames;
          dnsProvider = "rfc2136";
          credentialFiles = mkDns01Credentials;
          group = "acme";
          reloadServices = ["haproxy.service"];
        }) locallyIssuedCerts;
      };

      psyclyx.nixos.network.ports.haproxy-ingress = {
        tcp = [80 443];
      };
    })

    # --- Resolver side: localzone records for localzone-view scopes ---
    (lib.mkIf (resolverLocalZoneRecords != []) {
      psyclyx.nixos.network.dns.resolver.localZones.${eg.domains.internal} = {
        type = "transparent";
        records = resolverLocalZoneRecords;
      };
    })

    # --- Authoritative side: zone records for authoritative-view scopes ---
    {
      psyclyx.nixos.network.dns.authoritative.zones = lib.mapAttrs (_: records: {
        extraRecords = lib.mkAfter records;
      }) authoritativeZoneRecords;
    }
  ];
}
