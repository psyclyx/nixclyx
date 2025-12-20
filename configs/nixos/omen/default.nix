{ inputs, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    ./filesystems.nix
  ];

  config = {
    networking.hostName = "omen";

    boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];

    # Development and specialized environments
    environment.systemPackages = with pkgs.psyclyx.envs; [
      shell
      languages
      llm
      media
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
        wireless = true;
      };

      programs = {
        adb.enable = true;
      };

      roles = {
        base.enable = true;
        graphical.enable = true;
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

      users = {
        psyc.enable = true;
      };
    };

    stylix = {
      image = inputs.self.assets.wallpapers."2x-ppmm-madoka-homura.png";
    };
  };
}
