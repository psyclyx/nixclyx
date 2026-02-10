{
  path = ["psyclyx" "nixos" "config" "roles" "workstation"];
  variant = ["psyclyx" "nixos" "role"];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    boot = {
      kernelPackages = pkgs.linuxPackages_zen;
    };

    environment.systemPackages =
      nixclyx.packageGroups.dev pkgs
      ++ [
        pkgs.mpv
        pkgs.vlc
      ];

    home-manager.users.psyc.psyclyx.home.variant = "workstation";

    psyclyx.nixos = {
      config = {
        roles.base.enable = true;
        users.psyc.enable = true;
      };

      network.dns.client.enable = true;

      programs = {
        sway.enable = lib.mkDefault true;
        qmk.enable = lib.mkDefault true;
        nvf.enable = lib.mkDefault true;
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
