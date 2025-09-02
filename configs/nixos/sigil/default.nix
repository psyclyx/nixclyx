{ inputs, pkgs, ... }:
{
  system.stateVersion = "25.05";
  networking.hostName = "sigil";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.disko.nixosModules.disko
    inputs.stylix.nixosModules.stylix

    ../../../modules/nixos/module.nix
    ../../../modules/nixos/system/home-manager.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];

  psyclyx = {
    roles = {
      base.enable = true;
      graphical.enable = true;
      media.enable = true;
      remote.enable = true;
      utility.enable = true;
    };
    hardware = {
      glasgow = {
        # 28-08-2025 workaround build failure
        enable = false;
        # enable = true;
        users = [ "psyc" ];
      };
    };
    programs = {
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
