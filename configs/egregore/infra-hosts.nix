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
          dnsAuthority = ["psyclyx.net" "psyclyx.xyz" "psyclyx.link"];
          publicAcme = true;
          # `tleilax.psyclyx.xyz` + `vpn.psyclyx.xyz` — both point at
          # the public IP. vpn is the WG-hub endpoint; tleilax is the
          # host's own public name.
          publicNames = [ "tleilax" "vpn" ];
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
          # iyr is the apt site gateway for main/infra/guest/iot/mgmt
          # and an L2-only DHCP/DNS listener on storage/lab (mdf-agg01
          # is their L3 gateway). Declaring the full interface set
          # lets data-driven projections (overlay shortcuts, firewall
          # zones) target the right units without per-host scaffolding.
          interfaces = {
            main.device    = "enp1s0.10";
            infra.device   = "enp1s0.25";
            guest.device   = "enp1s0.100";
            iot.device     = "enp1s0.110";
            storage.device = "enp1s0.200";
            lab.device     = "enp1s0.210";
            mgmt.device    = "enp1s0.240";
            vpn.device     = "wg0";
          };
          mac = {
            enp1s0 = "c8:ff:bf:06:2c:4e";   # LAN trunk parent
            enp3s0 = "c8:ff:bf:06:2c:4d";   # WAN
          };
          gateway = {
            lanInterface = "enp1s0";
            wanInterface = "enp3s0";
            lanAddress = "10.0.0.11/24";    # untagged trunk (legacy setup VLAN 1)
            initrdVlans = [ "main" "mgmt" ];
            initrdKernelModules = [ "8021q" "igc" ];
            transitDhcpV6.duidRawData = "e7:13:f8:92:37:c5:be:76";
            # Comcast/Xfinity DHCP sends option-121 classless static
            # routes with no 0.0.0.0/0, which (per RFC 3442) suppresses
            # the option-3 gateway and leaves enp3s0.250 with no default
            # route. Ignore option 121 so networkd installs the gateway
            # as the main-table default — this is the always-on IPv4
            # fallback the Google Fiber failover falls back to.
            transitDhcpV4.useRoutes = false;
            # Xfinity apartment uplink — symmetric 2.2 Gbps provisioned.
            # Min kept lower for graceful autorate degradation; max
            # gives small headroom past nominal.
            cakeQos = {
              download = { min = 1400000; base = 2200000; max = 2280000; };
              upload   = { min = 1400000; base = 2200000; max = 2280000; };
            };
          };
          firewall = {
            # enp1s0 (untagged trunk parent) shares trust with main →
            # join the lan zone. enp3s0.250/.251 are the WAN VLAN
            # sub-ifaces (transit isn't modeled as a network entity
            # since it has no internal subnet). .250 is Xfinity (IPv6 +
            # IPv4 fallback), .251 is Google Fiber (the primary IPv4
            # uplink) — see hosts/nixos/iyr/default.nix; both share the
            # WAN drop+ICMP+DHCP-client posture.
            zones = {
              lan.extraInterfaces  = [ "enp1s0" ];
              wan.extraInterfaces  = [ "enp3s0.250" "enp3s0.251" ];
            };
            input = {
              # Internal zones: trusted.
              lan = "accept";
              infra = "accept";
              storage = "accept";
              lab-transit = "accept";
              mgmt = "accept";
              wg = "accept";
              # Guests + IoT: permissive at iyr (they go through this
              # gateway anyway). Override here, not in NixOS module.
              guest = "accept";
              iot = "accept";
              # WAN: drop + specific allows. The TCP port comes from
              # the SSH service port; hardcoded here pending a port
              # registry projection.
              wan = {
                policy = "drop";
                allowICMP = true;
                allowedTCPPorts = [ 17891 ];   # ssh
                rules = [
                  {
                    "udp sport" = 67;
                    "udp dport" = 68;
                    comment = "DHCPv4 client";
                  }
                  {
                    "udp dport" = 546;
                    comment = "DHCPv6 client";
                  }
                ];
              };
            };
            masquerade = [
              # Apt-LAN zones egressing to WAN.
              { from = "lan"; to = "wan"; }
              { from = "infra"; to = "wan"; }
              { from = "guest"; to = "wan"; }
              { from = "iot"; to = "wan"; }
              # WG-routed traffic to apt zones needs source NAT.
              # WG cryptokey check at the hub drops sources outside
              # the peer's AllowedIPs; masquerading at iyr makes
              # apt-side traffic look locally-originated so replies
              # come back through iyr.
              { from = "wg"; to = "lan"; }
              { from = "wg"; to = "infra"; }
            ];
          };
          addresses = {
            vpn.ipv4     = "10.157.0.2";
            lab.ipv4     = "10.0.210.2";
            storage.ipv4 = "10.0.200.2";
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
        # /persist is consumed locally from sigil's own rpool. /nix
        # is still on bcachefs during the slow ZFS cutover and is
        # intentionally not declared here.
        refs.persistDataset = "sigil-persist";
        host = {
          site = "apt";
          wireguard = {
            publicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
            allowedNetworks = [];
          };
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
          # NFS to lab-4 over main VLAN: principal must match the
          # FQDN sigil resolves lab-4 to (sigil.main.apt.psyclyx.net).
          kerberos.fqdnNetwork = "main";
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
