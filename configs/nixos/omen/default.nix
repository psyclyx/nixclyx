{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    ./filesystems.nix
  ];

  config = {
    networking.hostName = "omen";

    boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];

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
        wireless = true;
      };

      programs = {
        adb.enable = true;
      };

      roles = {
        base.enable = true;
        dev.enable = true;
        graphical.enable = true;
        media.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      services = {
        fstrim.enable = true;
        kanata.enable = true;
        resolved.enable = true;
        thermald.enable = true;
      };

      system = {
        emulation.enable = true;
      };

      stylix = {
        image = inputs.self.assets.wallpapers."2x-ppmm-madoka-homura.png";
        dark = true;
      };

      users.psyc = {
        enable = true;
      };
    };
  };
}
