{ inputs, pkgs, ... }:
{
  system.stateVersion = "25.05";
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.stylix.nixosModules.stylix
    ../../../modules/nixos/module.nix

    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];

  psyclyx = {
    hardware = {
      cpu = {
        enableMitigations = false;
        intel.enable = true;
      };
      gpu.intel.enable = true;
    };
    roles = {
      base.enable = true;
      graphical.enable = true;
      media.enable = true;
      remote.enable = true;
      utility.enable = true;
    };
    services = {
      locate = {
        users = [ "psyc" ];
      };
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
