{
  path = ["psyclyx" "nixos" "hosts" "iyr"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./networkd.nix ./dhcp.nix ./dns.nix];
  config = {
    lib,
    config,
    nixclyx,
    ...
  }: let
    topo = config.psyclyx.topology;
    dt = nixclyx.lib.topology lib topo;
    sortedNets = map (vlan:
      dt.networks.${dt.vlanNameMap.${toString vlan}})
    dt.dhcpVlans;
  in {
    networking.hostName = "iyr";

    # WireGuard extras (topology module handles base wg0 config)
    networking.firewall.trustedInterfaces = ["wg0"];

    psyclyx.nixos = {
      boot = {
        initrd-ssh.enable = true;
      };

      filesystems.layouts.bcachefs-pool = {
        enable = true;
        UUID = {
          root = "0b6d93c8-c6d3-4243-9413-25543a093c65";
          boot = "0289-61AC";
        };
      };

      hardware = {
        cpu.intel.enable = true;
        gpu.intel.enable = true;
      };

      network.dns = {
        client.enable = true;
        resolver = {
          enable = true;
          interfaces =
            ["10.0.0.11"]
            ++ map (net: net.gateway4) sortedNets
            ++ ["10.157.0.2"]
            ++ map (net: net.gateway6) sortedNets
            ++ ["::"];
          accessControl = [
            "10.0.0.0/8 allow"
            "${topo.ipv6UlaPrefix}::/48 allow"
            "fe80::/10 allow"
            "::1/128 allow"
          ];
          forwardZones = {
            "psyclyx.net" = {
              forward-addr = ["10.157.0.1"];
            };
          };
        };
      };

      role = "server";

      services = {
        prometheus.collector.enable = true;
        kiosk = {
          enable = true;
          url = "https://metrics.psyclyx.net";
        };
      };
    };
  };
}
