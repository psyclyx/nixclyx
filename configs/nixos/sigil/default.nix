{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    ./filesystems.nix
  ];

  config = {
    networking.hostName = "sigil";

    psyclyx = {
      hardware = {
        cpu = {
          amd.enable = true;
          enableMitigations = false;
        };
        glasgow.enable = true;
        gpu.nvidia.enable = true;
      };

      network.enable = true;

      roles = {
        base.enable = true;
        dev.enable = true;
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
        resolved.enable = true;
        tailscale.exitNode = true;
      };

      system = {
        emulation.enable = true;
      };

      stylix = {
        image = inputs.self.assets.wallpapers."4x-ppmm-mami.jpg";
        dark = true;
      };

      users.psyc = {
        enable = true;
      };
    };
  };
}
