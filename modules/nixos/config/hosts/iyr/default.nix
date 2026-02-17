{
  path = ["psyclyx" "nixos" "config" "hosts" "iyr"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix];
  config = {lib, ...}: {
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
          interfaces = [
            "10.0.0.11"
            "10.0.10.1"
            "10.0.20.1"
            "10.0.21.1"
            "10.0.22.1"
            "10.0.23.1"
            "10.0.240.1"
            "10.157.0.2"
            "fd9a:e830:4b1e:a::1"
            "fd9a:e830:4b1e:14::1"
            "fd9a:e830:4b1e:15::1"
            "fd9a:e830:4b1e:16::1"
            "fd9a:e830:4b1e:17::1"
            "fd9a:e830:4b1e:f0::1"
            "::"
          ];
          accessControl = [
            "10.0.0.0/8 allow"
            "fd9a:e830:4b1e::/48 allow"
            "fe80::/10 allow"
            "::1/128 allow"
          ];
        };
      };

      role = "server";

      services.kiosk = {
        enable = true;
        url = "https://metrics.psyclyx.net";
      };
    };
  };
}
