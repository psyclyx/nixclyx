{
  path = ["psyclyx" "nixos" "config" "hosts" "tleilax"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix ./wireguard.nix];
  config = {
    nixclyx,
    ...
  }: {
    networking.hostName = "tleilax";

    fileSystems = {
      "/" = {
        device = "UUID=a5823c8f-07c7-41c5-ad9f-4782cb5ba154";
        fsType = "ext4";
      };
      "/boot" = {
        device = "UUID=C8F3-8E47";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    psyclyx.nixos = {
      hardware.presets.hpe.dl20-gen10.enable = true;

      network = {
        ports.ssh = [17891];

        dns = {
          authoritative = {
            ns = "199.255.18.171";
            interfaces = ["199.255.18.171" "2606:7940:32:26::10"];
            port = 53;
            zones = {
              "psyclyx.xyz" = {
                ttl = 3600;
                extraRecords = ''
                  vpn    IN A     199.255.18.171
                '';
              };
            };
          };
          resolver = {
            enable = true;
            interfaces = ["10.157.0.1"];
            accessControl = ["10.157.0.0/24 allow"];
            localZones = {
              "psyclyx.net" = {
                type = "static";
                records = [
                  "tleilax.psyclyx.net. IN A 10.157.0.1"
                  "sigil.psyclyx.net. IN A 10.157.0.3"
                  "iyr.psyclyx.net. IN A 10.157.0.2"
                ];
              };
              "psyclyx.xyz" = {
                type = "transparent";
                # Split horizon: internal overrides go here
                # Queries without local-data fall through to NSD (public answers)
              };
            };
          };
        };
      };

      role = "server";

      services = {
        tailscale.exitNode = true;

        nginx = {
          enable = true;
          acme.email = "me@psyclyx.xyz";
          virtualHosts."docs.psyclyx.xyz" = {
            root = nixclyx.docs;
          };
        };
      };
    };
  };
}
