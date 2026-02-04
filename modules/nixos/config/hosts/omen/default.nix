{
  config,
  lib,
  pkgs,
  nixclyx,
  ...
}: let
  cfg = config.psyclyx.nixos.config.hosts.omen;
in {
  imports = [
    ./filesystems.nix
  ];

  options.psyclyx.nixos.config.hosts.omen = {
    enable = lib.mkEnableOption "omen host";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "omen";

    boot.kernelParams = ["snd-intel-dspcfg.dsp_driver=1"];

    environment.systemPackages = let
      inherit (pkgs.psyclyx) envs;
    in [
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

        config = {
          roles.workstation.enable = true;
        };
      };
    };

    stylix = {
      image = nixclyx.assets.wallpapers."2x-ppmm-madoka-homura.png";
      polarity = "dark";
    };
  };
}
