# Ingress projection — generates haproxy, ACME, and DNS config from
# service entities on the overlay hub (ingress host).
#
# HAProxy terminates TLS and routes by Host header to backends.
# Nginx (localhost-only) serves static files as just another backend.
# TCP services get DNS records only (no haproxy frontend).
{ config, lib, pkgs, ... }: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname};

  isIngress = hostname == eg.overlay.hub;

  services = lib.filterAttrs (_: e: e.type == "service") eg.entities;
  httpServices = lib.filterAttrs (_: e: e.service.protocol == "http") services;
  tcpServices = lib.filterAttrs (_: e: e.service.protocol == "tcp") services;

  # Domain tier classification — determines listen address, ACME strategy, DNS zone.
  # Environment domains are checked before internal because they're subdomains
  # of the internal domain (e.g. stage.psyclyx.net under psyclyx.net).
  envDomains = lib.mapAttrsToList (_: e: e.environment.domain)
    (lib.filterAttrs (_: e: e.type == "environment" && e.environment.domain != null) eg.entities);

  domainTier = domain:
    if lib.hasSuffix ".${eg.domains.public}" domain
    then "public"
    else if builtins.any (d: lib.hasSuffix ".${d}" domain || domain == d) envDomains
    then "environment"
    else if lib.hasSuffix ".${eg.domains.internal}" domain
    then "internal"
    # Domains not matching any tier (e.g. psyclyx.link) are public.
    else "public";

  tierOf = name: domainTier (services.${name}).attrs.resolvedDomain;

  # Partition HTTP services by which haproxy frontend they belong to.
  publicHttp = lib.filterAttrs (n: _: tierOf n == "public" || tierOf n == "environment") httpServices;
  internalHttp = lib.filterAttrs (n: _: tierOf n == "internal") httpServices;

  publicAddr = me.host.publicIPv4;
  vpnAddr = me.host.addresses.vpn.ipv4;

  authCfg = config.psyclyx.nixos.network.dns.authoritative;

  # ACME credential files for DNS-01 via RFC 2136 (shared by all wildcard certs).
  mkDns01Credentials = {
    "RFC2136_NAMESERVER_FILE" = pkgs.writeText "rfc2136-ns" "${builtins.head authCfg.interfaces}:${toString authCfg.port}";
    "RFC2136_TSIG_ALGORITHM_FILE" = pkgs.writeText "rfc2136-algo" "hmac-sha256.";
    "RFC2136_TSIG_KEY_FILE" = pkgs.writeText "rfc2136-keyname" authCfg.tsigKeyName;
    "RFC2136_TSIG_SECRET_FILE" = authCfg.tsigSecretFile;
  };

  # Collect unique environment domains that have services.
  envDomainsWithServices = lib.unique (lib.concatMap (e:
    let svc = e.service;
    in if svc.environment != null
       then [eg.entities.${svc.environment}.environment.domain]
       else []
  ) (builtins.attrValues httpServices));

  # --- HAProxy config generation ---

  mkBackend = name: entity: let
    a = entity.attrs;
    s = entity.service;
    opts = lib.concatStringsSep "\n" (
      lib.optional s.websockets "    option http-server-close"
      ++ lib.optionals (s.check != null) [
        "    option httpchk"
        "    http-check send meth GET uri ${s.check} ver HTTP/1.1 hdr Host localhost"
        "    http-check expect status 200"
      ]
    );
  in ''

    backend bk_svc_${name}
      mode http
  '' + lib.optionalString (opts != "") (opts + "\n")
     + "    server srv1 ${a.resolvedAddress}:${toString a.resolvedPort} check inter 10s\n";

  # Collect unique cert domains needed for a set of services.
  certDomainsFor = svcs: lib.unique (lib.mapAttrsToList (name: e:
    let
      domain = e.attrs.resolvedDomain;
      tier = tierOf name;
    in
      # Public services use per-domain certs; internal use wildcard;
      # environment services use their env's wildcard.
      if tier == "internal" then eg.domains.internal
      else if tier == "environment" then
        (builtins.head (builtins.filter (d:
          lib.hasSuffix ".${d}" domain || domain == d
        ) envDomains))
      else domain
  ) svcs);

  mkFrontend = frontendName: bindAddr: svcs: let
    svcList = lib.mapAttrsToList lib.nameValuePair svcs;
    crtFiles = lib.concatMapStringsSep " "
      (d: "crt /var/lib/acme/${d}/full.pem")
      (certDomainsFor svcs);
    acls = map
      (s: "    acl host_${s.name} hdr(host) -i ${s.value.attrs.resolvedDomain}")
      svcList;
    useBackends = map
      (s: "    use_backend bk_svc_${s.name} if host_${s.name}")
      svcList;
  in ''

    frontend ft_https_${frontendName}
      bind ${bindAddr}:443 ssl ${crtFiles} strict-sni
      mode http
      option forwardfor
      http-request set-header X-Forwarded-Proto https
  '' + lib.concatStringsSep "\n" acls + "\n"
     + lib.concatStringsSep "\n" useBackends + ''


    frontend ft_http_${frontendName}
      bind ${bindAddr}:80
      mode http
      redirect scheme https code 301
  '';

  backends = lib.concatStringsSep "" (lib.mapAttrsToList mkBackend httpServices);

  haproxyConfig = ''
    global
      log stdout local0
      maxconn 4096
      stats socket /run/haproxy/admin.sock mode 660 level admin

    defaults
      log global
      option dontlognull
      timeout connect 5s
      timeout client 50s
      timeout server 50s
      retries 3
  '' + mkFrontend "public" publicAddr publicHttp
     + mkFrontend "internal" vpnAddr internalHttp
     + backends;

  # --- DNS record generation ---

  # Internal HTTP services: resolver localZone pointing to VPN IP.
  # All internal traffic goes through ingress haproxy for TLS termination,
  # even HA-backed services — VPN clients may not have routes to VIPs.
  internalDnsRecords = lib.mapAttrsToList (_: e:
    "${e.attrs.resolvedDomain}. IN A ${vpnAddr}"
  ) internalHttp;

  # TCP services with HA backends: resolver localZone pointing to VIP directly.
  tcpDnsRecords = lib.concatLists (lib.mapAttrsToList (_: e:
    let a = e.attrs;
    in lib.optional (a.backendType == "ha" && a.resolvedAddress != null)
      "${a.resolvedDomain}. IN A ${a.resolvedAddress}"
  ) tcpServices);

  # Public HTTP services: authoritative DNS A/AAAA records.
  publicDnsRecords = lib.concatMapStringsSep "\n" (e: let
    # Extract subdomain from FQDN.
    domain = e.attrs.resolvedDomain;
  in
    # Only generate for subdomains of known zones; top-level domains
    # (like psyclyx.link) have their own zone config.
    if lib.hasSuffix ".${eg.domains.public}" domain then let
      sub = lib.removeSuffix ".${eg.domains.public}" domain;
    in ''
      ${sub}    IN A     ${publicAddr}
      ${sub}    IN AAAA  ${me.host.publicIPv6}''
    else ""
  ) (builtins.attrValues publicHttp);

  # Stage/environment services: authoritative DNS records per env zone.
  envDnsRecords = builtins.listToAttrs (map (envDomain:
    let
      envSvcs = lib.filter (e:
        e.service.environment != null
        && eg.entities.${e.service.environment}.environment.domain == envDomain
      ) (builtins.attrValues httpServices);
      records = lib.concatMapStringsSep "\n" (e: let
        sub = lib.removeSuffix ".${envDomain}" e.attrs.resolvedDomain;
      in ''
        ${sub} IN A     ${publicAddr}
        ${sub} IN AAAA  ${me.host.publicIPv6}'') envSvcs;
    in lib.nameValuePair envDomain records
  ) envDomainsWithServices);

in {
  config = lib.mkIf isIngress {
    # --- HAProxy ---
    services.haproxy = {
      enable = true;
      config = haproxyConfig;
    };

    systemd.services.haproxy = {
      after = ["network-online.target" "acme-selfsigned-certificates.target"];
      wants = ["network-online.target"];
    };

    # haproxy needs to read ACME certs.
    users.users.haproxy.extraGroups = ["acme"];

    # --- ACME ---
    # ACME defaults — email sourced from nginx module (still enabled for
    # static file serving). Will migrate to a dedicated option later.
    security.acme = {
      acceptTerms = true;
      defaults.email = config.psyclyx.nixos.services.nginx.acme.email;
    };

    security.acme.certs = let
      mkCert = domain: extra: {
        inherit domain;
        dnsProvider = "rfc2136";
        credentialFiles = mkDns01Credentials;
        group = "acme";
        reloadServices = ["haproxy.service"];
      } // extra;

      # Wildcard cert for *.psyclyx.net (internal services).
      internalWildcard = {
        "psyclyx.net" = mkCert "psyclyx.net" {
          extraDomainNames = ["*.psyclyx.net"];
        };
      };

      # Wildcard certs for environment domains (e.g. *.stage.psyclyx.net).
      envWildcards = builtins.listToAttrs (map (envDomain:
        lib.nameValuePair envDomain (mkCert envDomain {
          extraDomainNames = ["*.${envDomain}"];
        })
      ) envDomainsWithServices);

      # Per-domain certs for public services (DNS-01).
      publicCerts = builtins.listToAttrs (lib.concatLists (
        lib.mapAttrsToList (name: e: let
          domain = e.attrs.resolvedDomain;
          tier = tierOf name;
        in
          lib.optional (tier == "public") (lib.nameValuePair domain (mkCert domain {}))
        ) httpServices
      ));
    in internalWildcard // envWildcards // publicCerts;

    # --- DNS: resolver localZones for internal + TCP services ---
    psyclyx.nixos.network.dns.resolver.localZones."psyclyx.net" = {
      type = "transparent";
      records = internalDnsRecords ++ tcpDnsRecords;
    };

    # DNS: localZone for psyclyx.link (split-horizon → VPN IP).
    psyclyx.nixos.network.dns.resolver.localZones."psyclyx.link" = {
      type = "transparent";
      records = ["psyclyx.link. IN A ${vpnAddr}"];
    };

    # --- DNS: authoritative zone records ---
    psyclyx.nixos.network.dns.authoritative.zones =
      # Public service A/AAAA records in psyclyx.xyz zone.
      { "psyclyx.xyz".extraRecords = lib.mkAfter publicDnsRecords; }
      # Environment service records (e.g. stage.psyclyx.net zone).
      // builtins.mapAttrs (_: records: {
        extraRecords = lib.mkAfter records;
      }) envDnsRecords;

    # --- Firewall ---
    psyclyx.nixos.network.ports.haproxy-ingress = {
      tcp = [80 443];
    };
  };
}
