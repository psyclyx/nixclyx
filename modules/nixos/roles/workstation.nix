{
  path = ["psyclyx" "nixos" "roles" "workstation"];
  variant = ["psyclyx" "nixos" "role"];
  config = {
    lib,
    pkgs,
    config,
    nixclyx,
    ...
  }: let
    # pkgs.linux_zen tracks the newest zen release (currently 7.1.x), but
    # zfs_2_4 caps at kernel 7.0 and marks its module broken above that.
    # Rebuild the zen kernel from the newest zen tag ZFS still supports so
    # ZFS hosts keep the zen patchset instead of dropping to stock.
    linuxPackages_zen_zfs = pkgs.linuxPackagesFor (pkgs.linux_zen.override {
      argsOverride = rec {
        version = "7.0.14";
        modDirVersion = "${version}-zen1";
        src = pkgs.fetchFromGitHub {
          owner = "zen-kernel";
          repo = "zen-kernel";
          rev = "v${version}-zen1";
          sha256 = "1fcxrizyhichfwp2541113zij663j0nnizg2lfk0kfky59mlmcal";
        };
      };
    });
  in {
    boot = {
      kernelPackages = lib.mkDefault (
        if config.boot.zfs.enabled
        then linuxPackages_zen_zfs
        else pkgs.linuxPackages_zen
      );
    };

    environment.systemPackages =
      nixclyx.packageGroups.dev pkgs
      ++ nixclyx.packageGroups.media pkgs
      ++ [
        pkgs.mpv
        pkgs.vlc
        pkgs.psyclyx.ilo

        # Graphics / creative
        pkgs.blender
        pkgs.inkscape
        pkgs.gimp
        pkgs.krita
        pkgs.pinta
      ];

    home-manager.users.psyc = {
      psyclyx.home.profiles.psyc = {
        base.enable = true;
        desktop.enable = true;
      };
      psyclyx.home.programs.nvf.enable = lib.mkDefault true;
      psyclyx.home.programs.river.enable = lib.mkDefault true;
    };

    psyclyx.nixos = {
      roles.base.enable = true;
      users.psyc.enable = true;

      network.dns.client.enable = true;

      programs = {
        adb.enable = lib.mkDefault true;
        ccache.enable = lib.mkDefault true;
        river.enable = lib.mkDefault true;
        sway.enable = lib.mkDefault true;
      };

      services = {
        gdm.enable = lib.mkDefault true;
        gnome-keyring.enable = lib.mkDefault true;
        gnupg-agent.enable = lib.mkDefault true;
        printing.enable = lib.mkDefault true;
      };

      system = {
        fonts.enable = lib.mkDefault true;
        stylix.enable = lib.mkDefault true;
      };
    };
  };
}
