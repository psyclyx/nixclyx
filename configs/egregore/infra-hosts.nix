# Infrastructure hosts — servers and endpoints outside the lab rack.
{
  gate = "always";
  config = {
    entities = {
      tleilax = {
        type = "host";
        tags = ["server" "colo" "fixed"];
        host = {
          site = "cofractal-sea";
          wireguard = {
            publicKey = "Hsytr+mjAfsBPoC99XHKLh9+jEbyz1REF0okmlviUVc=";
            endpoint  = "vpn.psyclyx.xyz:51820";
            port = 51820;
            allowedNetworks = ["main"];
          };
          addresses = {
            vpn.ipv4 = "10.157.0.1";
            public = {
              ipv4 = "199.255.18.171";
              ipv6 = "2606:7940:32:26::10";
            };
          };
          dnsAuthority = ["psyclyx.net" "psyclyx.xyz" "psyclyx.link" "angelbeats.me"];
          publicAcme = true;
          sshPort = 17891;
          deployAddress = "199.255.18.171";
          roles = ["server" "vpn-hub"];
          exporters = {
            node     = { port = 9100; networks = ["vpn"]; };
            smartctl = { port = 9633; networks = ["vpn"]; };
          };
        };
      };

      iyr = {
        type = "host";
        tags = ["server" "apartment" "router" "fixed"];
        host = {
          site = "apt";
          wireguard = {
            publicKey = "9wnevbvkDGcyNnMECEzgfaghqi4tEw4GsgC/TUcSTS4=";
            # Apartment subnets advertised to VPN peers. storage/lab are
            # routed by mdf-agg01, but iyr still forwards there via its
            # static routes on vlan10, so peers reach them transparently.
            exportedRoutes = [
              "10.0.10.0/24"  "10.0.25.0/24"  "10.0.100.0/24" "10.0.110.0/24"
              "10.0.200.0/24" "10.0.210.0/24" "10.0.240.0/24"
            ];
          };
          # iyr is the apt site gateway; the gateway projection wires
          # most VLANs onto enp1s0. Declaring main here lets data-driven
          # projections (e.g. overlay shortcuts) target the right unit.
          # iyr also participates on the lab VLAN as an L2-only DHCP
          # listener — lab is gateway'd by mdf-agg01, but iyr serves
          # the boot-file-name / next-server options for PXE clients.
          interfaces = {
            main.device = "enp1s0.10";
            lab.device  = "enp1s0.210";
          };
          addresses = {
            vpn.ipv4 = "10.157.0.2";
            lab.ipv4 = "10.0.210.2";
          };
          sshPort = 17891;
          deployAddress = "iyr.apt.psyclyx.net";
          roles = ["server" "router"];
          hardware.tpm = true;
          exporters = {
            node     = { port = 9100; networks = ["vpn"]; };
            smartctl = { port = 9633; networks = ["vpn"]; };
          };
        };
      };

      sigil = {
        type = "host";
        tags = ["workstation" "desktop" "apartment" "fixed"];
        host = {
          site = "apt";
          wireguard = {
            publicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
            allowedNetworks = [];
          };
          interfaces.main.device = "br0";
          addresses = {
            vpn.ipv4 = "10.157.0.3";
            main.dhcp = true;
          };
          roles = ["workstation"];
          deployAddress = "sigil.apt.psyclyx.net";
          hardware.tpm = true;
          exporters = {
            node     = { port = 9100; networks = ["vpn"]; };
            smartctl = { port = 9633; networks = ["vpn"]; };
          };
        };
      };

      phone = {
        type = "host";
        tags = ["mobile"];
        host = {
          wireguard = {
            publicKey = "SaYcJM6Fl1UhX1qzby9rjUJv+icRyh29jX+iIqFKdDw=";
            allowedNetworks = ["main" "infra"];
          };
          addresses.vpn.ipv4 = "10.157.0.4";
          roles = ["mobile"];
        };
      };

      omen = {
        type = "host";
        tags = ["workstation" "laptop"];
        host = {
          wireguard = {
            publicKey = "yTRNWKLNu6Xb+h7DcPPiWohWe0O6QSwJBlh5AjzChmU=";
            allowedNetworks = ["main" "infra"];
          };
          addresses.vpn.ipv4 = "10.157.0.5";
          roles = ["workstation"];
        };
      };

      glyph = {
        type = "host";
        tags = ["workstation" "laptop"];
        host = {
          wireguard = {
            publicKey = "7ufcd0IzKRR85YMIh0mfoxaG14uwW09c/h4AJaAC1xY=";
            allowedNetworks = ["main" "infra"];
          };
          addresses.vpn.ipv4 = "10.157.0.6";
          roles = ["workstation"];
        };
      };

      semuta = {
        type = "host";
        tags = ["server" "vps" "fixed"];
        host = {
          site = "hetzner-pdx";
          wireguard = {
            publicKey = "co3+vTgO4y2IPzQOH9cNLl0fjFDrkzsukUNL9gR75TI=";
            allowedNetworks = ["main"];
          };
          addresses = {
            vpn.ipv4 = "10.157.0.7";
            public = {
              ipv4 = "5.78.144.186";
              ipv6 = "2a01:4ff:1f0:1a53::1";
            };
          };
          publicAcme = true;
          deployAddress = "5.78.144.186";
          roles = ["server"];
          exporters = {
            node = { port = 9100; networks = ["vpn"]; };
          };
        };
      };
    };
  };
}
