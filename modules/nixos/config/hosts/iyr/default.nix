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
      };

      network.dns.client.enable = true;

      role = "server";
    };
  };
}
