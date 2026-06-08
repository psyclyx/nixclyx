# Ingress projection — audience-driven.
#
# For every (service, audience) pair, the projection determines who runs
# ingress (service.attrs.effectiveIngress) and emits, on that host:
#
#   - one HAProxy backend per service (shared across audiences)
#   - one HAProxy frontend per audience, bound on this host's address
#     for that audience's network
#   - ACME cert config when this host can issue locally (its
#     dnsAuthority covers the cert's zone). Hosts that need a cert they
#     can't issue locally fetch it via the cert distribution module.
#   - resolver localZones records on the resolver host for non-public
#     audiences (audience.address resolves to a network entity whose
#     refs.dns names the resolver).
#   - authoritative zone A/AAAA records for the public audience, on
#     hosts with dnsAuthority for the matching zone.
#
# DNS resolution targets the *ingress host*'s address on the audience's
# network — so road warriors hitting tleilax's resolver for
# light.psyclyx.net get back iyr's vpn IP, not tleilax's, and there's
# no hairpin.
{ config, lib, pkgs, ... }: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  # `me` is null on hosts that aren't first-class egregore entities.
  # All usages below sit inside `mkIf`-guarded sections that are inert
  # on those hosts, so the null never propagates.
  me = eg.entities.${hostname} or null;

  services = lib.filterAttrs (_: e: e.type == "service") eg.entities;
  httpServices = lib.filterAttrs (_: e: e.service.protocol == "http") services;
  tcpServices = lib.filterAttrs (_: e: e.service.protocol == "tcp") services;

  audiences = eg.audiences;
  envEntities = lib.filterAttrs
    (_: e: e.type == "environment" && e.environment.domain != null)
    eg.entities;
  envDomains = lib.mapAttrsToList (_: e: e.environment.domain) envEntities;

  # --- Tuple expansion ---

  mkTuples = svcs: lib.concatLists (lib.mapAttrsToList (svcName: e:
    lib.mapAttrsToList (audName: ingHost: {
      inherit svcName audName ingHost;
      svc = e;
      audAddress = audiences.${audName}.address;
    }) e.attrs.effectiveIngress
  ) svcs);

  httpTuples = mkTuples httpServices;
  tcpTuples = mkTuples tcpServices;

  myIngressTuples = lib.filter (t: t.ingHost == hostname) httpTuples;
  myTuplesByAudience = builtins.groupBy (t: t.audName) myIngressTuples;

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
    intrinsic = h.host.dnsAuthority or [];
    sources = h.attrs.refsIn.dnsAuthority or [];
    contributed = lib.concatMap (n: let
      e = eg.entities.${n} or null;
    in lib.optional (e != null && e.type == "service" && e.attrs.resolvedDomain != null)
      e.attrs.resolvedDomain) sources;
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
    perTuple = map (t: certFor t.svc.attrs.resolvedDomain) myIngressTuples;
    byName = builtins.groupBy (c: c.name) perTuple;
  in lib.mapAttrs (_: cs: builtins.head cs) byName;

  # Certs I can issue locally — emitted as security.acme entries.
  locallyIssuedCerts = lib.filterAttrs (_: c: iCanIssue c.name) myCertSpecs;

  # --- HAProxy backend (one per service) ---

  mkBackend = svcName: e: let
    a = e.attrs;
    s = e.service;
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
     + "    server srv1 ${a.resolvedAddress}:${toString a.resolvedPort} check inter 10s\n";

  myBackendSvcs = lib.unique (map (t: t.svcName) myIngressTuples);
  backends = lib.concatStringsSep "" (map
    (n: mkBackend n httpServices.${n})
    myBackendSvcs);

  # --- HAProxy frontend (one per audience) ---

  mkFrontend = audName: tuples: let
    bind = me.attrs.addresses.${audiences.${audName}.address}.ipv4;
    certs = lib.unique (map (t: certPath (certFor t.svc.attrs.resolvedDomain).name) tuples);
    crtArgs = lib.concatMapStringsSep " " (p: "crt ${p}") certs;
    acls = map
      (t: "    acl host_${t.svcName} hdr(host) -i ${t.svc.attrs.resolvedDomain}")
      tuples;
    useBackends = map
      (t: "    use_backend bk_svc_${t.svcName} if host_${t.svcName}")
      tuples;
  in ''

    frontend ft_https_${audName}
      bind ${bind}:443 ssl ${crtArgs} strict-sni
      mode http
      option forwardfor
      http-request set-header X-Forwarded-Proto https
  '' + lib.concatStringsSep "\n" acls + "\n"
     + lib.concatStringsSep "\n" useBackends + ''


    frontend ft_http_${audName}
      bind ${bind}:80
      mode http
      redirect scheme https code 301
  '';

  frontends = lib.concatStringsSep ""
    (lib.mapAttrsToList mkFrontend myTuplesByAudience);

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

  # Ingress host's bind address for an audience's network — what DNS
  # records for that (audience, service) pair point at.
  ingressBindAddr = audAddress: ingHost: let
    addr = (eg.entities.${ingHost}.attrs.addresses.${audAddress} or null);
  in if addr != null then addr.ipv4 else null;

  # Resolver localzone records: emitted on the resolver host for each
  # network-backed audience (skips public). Pulls all (service, audience)
  # tuples whose audience.address resolves to a network entity served by
  # this host's resolver, including TCP services (which use the HA VIP
  # directly via service.attrs.resolvedAddress, not an ingress address).
  resolverLocalZoneRecords = let
    isResolverFor = audAddress: let
      net = eg.entities.${audAddress} or null;
    in net != null && net.type == "network" && (net.attrs.dnsRef or null) == hostname;

    httpRecs = lib.concatMap (t:
      lib.optional (isResolverFor t.audAddress)
        "${t.svc.attrs.resolvedDomain}. IN A ${ingressBindAddr t.audAddress t.ingHost}"
    ) httpTuples;

    tcpRecs = lib.concatMap (t: let
      a = t.svc.attrs;
    in
      lib.optional (isResolverFor t.audAddress
                    && a.resolvedAddress != null)
        "${a.resolvedDomain}. IN A ${a.resolvedAddress}"
    ) tcpTuples;
  in lib.unique (httpRecs ++ tcpRecs);

  # Authoritative public-zone records: emitted on hosts whose
  # dnsAuthority covers the matching zone, for services in the public
  # audience.
  publicTuples = lib.filter (t: t.audAddress == "public") httpTuples;

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
      domain = t.svc.attrs.resolvedDomain;
      zone = zoneFor domain;
      ingEntity = eg.entities.${t.ingHost};
      ipv4 = (ingEntity.attrs.addresses.public or { ipv4 = null; }).ipv4;
      ipv6 = (ingEntity.attrs.addresses.public or { ipv6 = null; }).ipv6;
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

    # --- Resolver side: localzone records for network-backed audiences ---
    (lib.mkIf (resolverLocalZoneRecords != []) {
      psyclyx.nixos.network.dns.resolver.localZones.${eg.domains.internal} = {
        type = "transparent";
        records = resolverLocalZoneRecords;
      };
    })

    # --- Authoritative side: zone records for public audience ---
    {
      psyclyx.nixos.network.dns.authoritative.zones = lib.mapAttrs (_: records: {
        extraRecords = lib.mkAfter records;
      }) authoritativeZoneRecords;
    }
  ];
}
