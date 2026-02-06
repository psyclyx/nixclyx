{
  path = ["psyclyx" "nixos" "services" "nsd"];
  description = "NSD authoritative DNS";
  options = {lib, ...}: {
    publicEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Public IP for NS records. Falls back to hub peer endpoint if not set.";
    };
    publicRecords = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional records appended to the psyclyx.xyz zone.";
    };
    additionalZones = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      description = "Additional authoritative zones (name -> zone data).";
      example = {
        "example.com" = ''
          $ORIGIN example.com.
          $TTL 3600
          @    IN SOA  ns.example.com. admin.example.com. (
                       1 3600 900 604800 300 )
          @    IN NS   ns.example.com.
          ns   IN A    192.0.2.1
        '';
      };
    };
  };
  config = {cfg, lib, nixclyx, ...}: let
    wg = nixclyx.wireguard;
    pki = nixclyx.pki;
    hub = wg.peers.${wg.rootHub};
    publicEndpoint = if cfg.publicEndpoint != null then cfg.publicEndpoint else hub.endpoint;

    privateZone = let
      records = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: peer: ''
        ${name}    IN A     ${peer.ip4}
        ${name}    IN AAAA  ${peer.ip6}
      '') wg.peers);
    in ''
      $ORIGIN psyclyx.net.
      $TTL 300
      @    IN SOA  ns.psyclyx.net. admin.psyclyx.net. (
                   1 3600 900 604800 300 )
      @    IN NS   ns.psyclyx.net.
      ns   IN A    ${hub.ip4}
      ns   IN AAAA ${hub.ip6}
      ${records}
    '';

    publicZone = ''
      $ORIGIN ${pki.dns.domain}.
      $TTL 3600
      @    IN SOA  ns.${pki.dns.domain}. admin.${pki.dns.domain}. (
                   1 3600 900 604800 300 )
      @    IN NS   ns.${pki.dns.domain}.
      ns   IN A    ${publicEndpoint}
      ns   IN AAAA ${hub.ip6}
      ${pki.dns.vpnSubdomain}   IN A     ${publicEndpoint}
      ${cfg.publicRecords}
    '';

    builtinZones = {
      "psyclyx.net".data = privateZone;
      "${pki.dns.domain}".data = publicZone;
    };

    additionalZones = lib.mapAttrs (name: data: { inherit data; }) cfg.additionalZones;
  in {
    services.nsd = {
      enable = true;
      interfaces = ["127.0.0.1" "::1" hub.ip4 hub.ip6];
      port = 5353;
      zones = builtinZones // additionalZones;
    };
  };
}
