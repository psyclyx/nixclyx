{
  path = ["psyclyx" "nixos" "roles" "workstation"];
  variant = ["psyclyx" "nixos" "role"];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    boot = {
      kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
    };

    environment.systemPackages =
      nixclyx.packageGroups.dev pkgs
      ++ [
        pkgs.mpv
        pkgs.vlc
        pkgs.psyclyx.ilo
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
