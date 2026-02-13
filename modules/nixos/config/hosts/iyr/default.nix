{
  path = ["psyclyx" "nixos" "config" "hosts" "iyr"];
  variant = ["psyclyx" "nixos" "host"];
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

      role = "server";
    };
  };
}
