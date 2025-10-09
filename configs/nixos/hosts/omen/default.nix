{ inputs, pkgs, ... }:
let
  inherit (inputs) self;
in
{
  networking.hostName = "omen";

  imports = [
    self.nixosModules.psyclyx
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
      containers.enable = true;
      emulation.enable = true;
      virtualization.enable = true;
    };
    stylix = {
      image = self.assets.wallpapers."2x-ppmm-madoka-homura.png";
      dark = true;
    };
  };
}
