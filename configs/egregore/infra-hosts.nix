# Infrastructure hosts — servers and endpoints outside the lab rack.
#
# Facets (wireguard, dnsAuthority, …, exporters) are top-level entity
# options, peers of `host`, not fields of it — see
# modules/egregore/aspects/host-facets.nix.
{
  gate = "always";
  config = {
    entities = {
      tleilax = {
        tags = ["server" "colo" "fixed" "vpn-hub"];
        host = {
          site = "cofractal-sea";
          addresses = {
            vpn.ipv4 = "10.157.0.1";
            public = {
              ipv4 = "199.255.18.171";
              ipv6 = "2606:7940:32:26::10";
            };
          };
        };
        # The management ssh listener (model §6) — declared: its port
        # and the places that reach it. The session account is the
        # client's (sshHosts.user).
        exposures.ssh = {
          role = "ssh";
          port = 17891;
          scopes = [ "public" "vpn" ];
        };
        wireguard = {
          publicKey = "Hsytr+mjAfsBPoC99XHKLh9+jEbyz1REF0okmlviUVc=";
          endpoint  = "vpn.psyclyx.xyz:51820";
          port = 51820;
          allowedNetworks = ["main"];
        };
        dnsAuthority = ["psyclyx.net" "psyclyx.xyz" "psyclyx.link"];
        publicAcme = true;
        # `tleilax.psyclyx.xyz` + `vpn.psyclyx.xyz` — both point at
        # the public IP. vpn is the WG-hub endpoint; tleilax is the
        # host's own public name.
        publicNames = [ "tleilax" "vpn" ];
        # Exporter exposures (model §6): one listener per exporter,
        # scraped from the vpn scope.
        exposures.node = {
          role = "exporter";
          port = 9100;
          scopes = [ "vpn" ];
        };
        exposures.smartctl = {
          role = "exporter";
          port = 9633;
          scopes = [ "vpn" ];
        };
      };

      iyr = {
        tags = ["server" "apartment" "router" "fixed"];
        host = {
          site = "apt";
          # mdf-agg01 is the v4 gateway for main, infra, storage and
          # lab; iyr holds a host address on each and remains their v6
          # router, their resolver and their DHCP server. It still
          # gateways mgmt and the transit /30 outright.
          #
          # Declaring the full interface set lets data-driven
          # projections (overlay shortcuts, firewall zones) target the
          # right units without per-host scaffolding.
          interfaces = {
            main.device    = "enp1s0.10";
            infra.device   = "enp1s0.25";
            storage.device = "enp1s0.200";
            lab.device     = "enp1s0.210";
            mgmt.device    = "enp1s0.240";
            core-transit.device = "enp1s0.252";
            vpn.device     = "wg0";
          };
          mac = {
            enp1s0 = "c8:ff:bf:06:2c:4e";   # LAN trunk parent
            enp3s0 = "c8:ff:bf:06:2c:4d";   # WAN
          };
          addresses = {
            vpn.ipv4     = "10.157.0.2";
            # .2 in both families on the segments iyr listens on but
            # doesn't gateway. The v6 halves were missing, and because
            # iyr is these networks' resolver, their DHCPv6 clients were
            # being handed mdf-agg01's ULA as a nameserver — a switch
            # that has never run a resolver.
            lab.ipv4     = "10.0.210.2";
            lab.ipv6     = "fd9a:e830:4b1e:d2::2";
            storage.ipv4 = "10.0.200.2";
            storage.ipv6 = "fd9a:e830:4b1e:c8::2";
            # iyr held 10.0.10.1 only by being main's v4 gateway, and
            # that moved to mdf-agg01 — so the address has to be stated
            # or iyr silently leaves the VLAN it resolves, serves DHCP
            # and is managed on. The v6 address stays derived: iyr is
            # still main's v6 router and holds ::1.
            main.ipv4    = "10.0.10.3";
            # Same story on infra: iyr held .1 by being its gateway, and
            # that moved to the switch. Everything that reaches OpenBao
            # and the resolver here derives the address from this entry,
            # so stating it is all that's needed.
            infra.ipv4   = "10.0.25.3";
          };
        };
        exposures.ssh = {
          role = "ssh";
          port = 17891;
          scopes = [ "apt" "vpn" ];
        };
        # Initrd ssh (early unlock, model §6): reserved at 8022 and
        # reachable from the segments whose gateway addresses come up
        # in initrd — the gateway projection reads these scopes.
        exposures.initrd-ssh = {
          role = "initrd-ssh";
          port = 8022;
          scopes = [ "main" "mgmt" ];
        };
        wireguard = {
          publicKey = "9wnevbvkDGcyNnMECEzgfaghqi4tEw4GsgC/TUcSTS4=";
          # Apartment subnets advertised to VPN peers. storage/lab are
          # routed by mdf-agg01, but iyr still forwards there via its
          # static routes on vlan10, so peers reach them transparently.
          exportedRoutes = [
            "10.0.10.0/24"  "10.0.25.0/24"
            "10.0.200.0/24" "10.0.210.0/24" "10.0.240.0/24"
          ];
        };
        hardware.tpm = true;
        exposures.node = {
          role = "exporter";
          port = 9100;
          scopes = [ "vpn" ];
        };
        exposures.smartctl = {
          role = "exporter";
          port = 9633;
          scopes = [ "vpn" ];
        };
      };

      sigil = {
        tags = ["workstation" "desktop" "apartment" "fixed"];
        # /persist is consumed locally from sigil's own rpool. /nix
        # is still on bcachefs during the slow ZFS cutover and is
        # intentionally not declared here.
        refs.persistDataset = "sigil-persist";
        host = {
          site = "apt";
          interfaces.main.device = "br0";
          addresses = {
            vpn.ipv4 = "10.157.0.3";
            # DHCP-acquired and genuinely dynamic — sigil's MAC isn't
            # modeled in egregore, so there's NO Kea reservation and no
            # stable address to declare. DNS is handled by DDNS: on
            # lease, Kea registers sigil.main.<zone> → the live address.
            # No ipv4 is declared (the host type explicitly allows this
            # for dhcp addresses). Consequences of the null address:
            # sigil gets no static apex A (reachable via sigil.main
            # DDNS), and overlay.nix emits no site-local /32 shortcut for
            # sigil's vpn IP — apt peers reach 10.157.0.3 over the WG
            # path instead. Pin the MAC + a Kea reservation if a stable
            # declared address is ever needed here.
            main.dhcp = true;
          };
        };
        exposures.ssh = {
          role = "ssh";
          port = 22;
          scopes = [ "apt" "vpn" ];
        };
        wireguard = {
          publicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
          allowedNetworks = [];
        };
        # NFS to lab-4 over main VLAN: principal must match the
        # FQDN sigil resolves lab-4 to (sigil.main.apt.psyclyx.net).
        kerberos.fqdnNetwork = "main";
        hardware.tpm = true;
        exposures.node = {
          role = "exporter";
          port = 9100;
          scopes = [ "vpn" ];
        };
        exposures.smartctl = {
          role = "exporter";
          port = 9633;
          scopes = [ "vpn" ];
        };
      };

      phone = {
        tags = ["mobile"];
        host = {
          addresses.vpn.ipv4 = "10.157.0.4";
        };
        exposures.ssh = {
          role = "ssh";
          port = 22;
          scopes = [ "vpn" ];
        };
        wireguard = {
          publicKey = "SaYcJM6Fl1UhX1qzby9rjUJv+icRyh29jX+iIqFKdDw=";
          allowedNetworks = ["main" "infra"];
        };
      };

      omen = {
        tags = ["workstation" "laptop"];
        host = {
          addresses.vpn.ipv4 = "10.157.0.5";
        };
        exposures.ssh = {
          role = "ssh";
          port = 22;
          scopes = [ "vpn" ];
        };
        wireguard = {
          publicKey = "yTRNWKLNu6Xb+h7DcPPiWohWe0O6QSwJBlh5AjzChmU=";
          allowedNetworks = ["main" "infra"];
        };
      };

      glyph = {
        tags = ["workstation" "laptop"];
        host = {
          addresses.vpn.ipv4 = "10.157.0.6";
        };
        exposures.ssh = {
          role = "ssh";
          port = 22;
          scopes = [ "vpn" ];
        };
        wireguard = {
          publicKey = "7ufcd0IzKRR85YMIh0mfoxaG14uwW09c/h4AJaAC1xY=";
          allowedNetworks = ["main" "infra"];
        };
      };

      semuta = {
        tags = ["server" "vps" "fixed"];
        host = {
          site = "hetzner-pdx";
          addresses = {
            vpn.ipv4 = "10.157.0.7";
            public = {
              ipv4 = "5.78.144.186";
              ipv6 = "2a01:4ff:1f0:1a53::1";
            };
          };
        };
        exposures.ssh = {
          role = "ssh";
          port = 22;
          scopes = [ "public" "vpn" ];
        };
        wireguard = {
          publicKey = "co3+vTgO4y2IPzQOH9cNLl0fjFDrkzsukUNL9gR75TI=";
          allowedNetworks = ["main"];
        };
        publicAcme = true;
        exposures.node = {
          role = "exporter";
          port = 9100;
          scopes = [ "vpn" ];
        };
      };
    };
  };
}
