{ inputs, pkgs, ... }:
{
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.self.nixosModules.psyclyx
    ./filesystems.nix
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
    network = {
      enable = true;
      networks."wlan0".enableDHCP = true;
      wireless = true;
    };
    roles = {
      base.enable = true;
      graphical.enable = true;
      media.enable = true;
      remote.enable = true;
      utility.enable = true;
    };
    services = {
      fstrim.enable = true;
      kanata.enable = true;
      locate = {
        users = [ "psyc" ];
      };
      thermald.enable = true;
    };
    system = {
      virtualization.enable = true;
    };
    stylix = {
      image = ../../wallpapers/2x-ppmm-madoka-homura.png;
      dark = true;
    };
  };
}
