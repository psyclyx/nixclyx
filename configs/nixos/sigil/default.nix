{ inputs, pkgs, ... }:
{
  networking.hostName = "sigil";
  imports = [
    inputs.self.nixosModules.psyclyx
    ./filesystems.nix
    ./users.nix
  ];

  psyclyx = {
    network = {
      enable = true;
      networks = {
        "enp5s0" = {
          enableDHCP = true;
          requiredForOnline = true;
        };
      };
      waitOnline = true;
    };
    roles = {
      base.enable = true;
      graphical.enable = true;
      media.enable = true;
      remote.enable = true;
      utility.enable = true;
    };
    hardware = {
      cpu = {
        amd.enable = true;
        enableMitigations = false;
      };
      glasgow = {
        # 28-08-2025 workaround build failure
        enable = false;
        # enable = true;
        users = [ "psyc" ];
      };
      gpu.nvidia.enable = true;
      rtl8125.disableEEEOn = [ "enp5s0" ];
    };
    programs = {
      adb = {
        enable = true;
        users = [ "psyc" ];
      };
      steam.enable = true;
    };
    services = {
      home-assistant.enable = true;
      openrgb.enable = true;
      locate = {
        users = [ "psyc" ];
      };
      tailscale.exitNode = true;
    };
    system = {
      virtualization.enable = true;
    };
    stylix = {
      image = ../../wallpapers/4x-ppmm-mami.jpg;
      dark = true;
    };
  };
}
