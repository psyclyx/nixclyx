{
  path = ["psyclyx" "nixos" "config" "hosts" "iyr"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix ./wireguard.nix];
  config = {lib, ...}: {
    networking.hostName = "iyr";

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
          ];
          accessControl = ["10.0.0.0/8 allow"];
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
