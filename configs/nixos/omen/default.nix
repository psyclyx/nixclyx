{ inputs, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.default
    ./filesystems.nix
  ];

  config = {
    networking.hostName = "omen";

    boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];

    environment.systemPackages =
      let
        inherit (pkgs.psyclyx) envs;
      in
      [
        envs.languages
        envs.llm
        envs.media
        envs.shell

        pkgs.android-tools
      ];

    psyclyx = {
      nixos = {
        hardware = {
          cpu = {
            enableMitigations = false;
            intel.enable = true;
          };

          gpu.intel.enable = true;
        };

        network.wireless.enable = true;

        services = {
          fstrim.enable = true;
          kanata.enable = true;
          resolved.enable = true;
          thermald.enable = true;
        };

        system = {
          emulation.enable = true;
        };

        roles = {
          base.enable = true;
          graphical.enable = true;
          remote.enable = true;
          utility.enable = true;
        };

        users = {
          psyc.enable = true;
        };
      };

    };

    stylix = {
      image = inputs.self.assets.wallpapers."2x-ppmm-madoka-homura.png";
      polarity = "dark";
    };
  };
}
