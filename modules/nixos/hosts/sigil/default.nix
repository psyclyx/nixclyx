{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (inputs.self.nixosModules) ;

  inherit (lib) mkEnableOption mkIf;
in
{
  imports = [
    inputs.self.nixosModules.psyclyx
    ./filesystems.nix
    ./network.nix
  ];

  config = {
    psyclyx = {
      hardware = {
        cpu = {
          amd.enable = true;
          enableMitigations = false;
        };
        glasgow.enable = true;
        gpu.nvidia.enable = true;
      };

      roles = {
        base.enable = true;
        forensics.enable = true;
        graphical.enable = true;
        media.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      programs = {
        adb.enable = true;
        steam.enable = true;
      };

      services = {
        avahi.enable = true;
        home-assistant.enable = true;
        openrgb.enable = true;
        tailscale.exitNode = true;
      };

      system = {
        emulation.enable = true;
      };

      stylix = {
        image = inputs.self.assets.wallpapers."4x-ppmm-mami.jpg";
        dark = true;
      };

      users.psyclyx.users.psyc = {
        enable = true;
        admin = true;
        hmModules = [ inputs.self.homeManagerModules.homes.psyc.pc ];
      };
    };
  };
}
