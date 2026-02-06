{
  path = ["psyclyx" "nixos" "services" "unbound"];
  description = "Unbound recursive DNS resolver";
  options = {lib, ...}: {
    additionalStubZones = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional zones to stub to local NSD.";
      example = ["example.com" "other.org"];
    };
  };
  config = {cfg, lib, nixclyx, ...}: let
    wg = nixclyx.wireguard;
    hub = wg.peers.${wg.hub};
    subnetAcl = map (s: "${s} allow") (wg.allSubnets4 ++ wg.allSubnets6);

    builtinStubs = ["psyclyx.net" "psyclyx.xyz"];
    allStubs = builtinStubs ++ cfg.additionalStubZones;
    stubZones = map (name: {
      inherit name;
      stub-addr = "127.0.0.1@5353";
    }) allStubs;
  in {
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = ["127.0.0.1" "::1" hub.ip4 hub.ip6];
          access-control = [
            "127.0.0.0/8 allow"
            "::1/128 allow"
          ] ++ subnetAcl;
          do-not-query-localhost = false;
        };
        stub-zone = stubZones;
        forward-zone = [
          {
            name = ".";
            forward-tls-upstream = true;
            forward-addr = [
              "1.1.1.1@853#cloudflare-dns.com"
              "1.0.0.1@853#cloudflare-dns.com"
            ];
          }
        ];
      };
    };

    services.resolved.settings.Resolve.DNSStubListener = false;
  };
}
