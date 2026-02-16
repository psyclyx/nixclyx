{
  path = ["psyclyx" "nixos" "config" "hosts" "iyr"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix ./wireguard.nix];
  config = {lib, ...}: {
    networking.hostName = "iyr";
    networking.extraHosts = "199.255.18.171 vpn.psyclyx.xyz";

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

      network.dns.client.enable = true;

      role = "server";

      services.kiosk = {
        enable = true;
        url = "https://metrics.psyclyx.xyz";
      };
    };
  };
}
