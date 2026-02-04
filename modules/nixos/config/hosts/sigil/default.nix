{
  config,
  lib,
  pkgs,
  nixclyx,
  ...
}: let
  cfg = config.psyclyx.nixos.config.hosts.sigil;
in {
  imports = [
    ./hardware.nix
    ./network.nix
  ];

  options.psyclyx.nixos.config.hosts.sigil = {
    enable = lib.mkEnableOption "sigil host";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "sigil";

    environment.systemPackages = let
      inherit (pkgs.psyclyx) envs;
    in [
      envs._3DPrinting
      envs.forensics
      envs.languages
      envs.llm
      envs.media
      envs.shell

      pkgs.android-tools
      pkgs.audacity
      pkgs.gimp-with-plugins
      pkgs.kicad
    ];

    psyclyx = {
      nixos = {
        filesystems.layouts.bcachefs-pool = {
          enable = true;
          UUID = {
            root = "ccb2b4e2-b5b7-4d85-aca8-039ca1ccc985";
            boot = "71AE-12DD";
          };
          wants = [
            "/dev/disk/by-id/nvme-eui.0025384c41416f3c"
            "/dev/disk/by-id/nvme-eui.ace42e00457c0fbf2ee4ac0000000001"
            "/dev/disk/by-id/ata-ST4000NM0035-1V4107_ZC12M6AQ" # hdd
            "/dev/disk/by-id/ata-WDC_WDS500G2B0A-00SM50_194894802985" # ssd
          ];
        };

        programs = {
          glasgow.enable = true;
          steam.enable = true;
        };

        config = {
          roles.workstation.enable = true;
        };

        services = {
          openrgb.enable = true;
          tailscale.exitNode = true;
        };

        system = {
          emulation.enable = true;
          swap.swappiness = 10;
        };
      };
    };

    stylix = {
      image = nixclyx.assets.wallpapers."4x-ppmm-mami.jpg";
      polarity = "dark";
    };
  };
}
