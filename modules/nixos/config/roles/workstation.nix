{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.config.roles.workstation;
in {
  options.psyclyx.nixos.config.roles.workstation = {
    enable = lib.mkEnableOption "workstation NixOS role";
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_zen;
    };

    environment.systemPackages = config.psyclyx.packageGroups.dev pkgs;

    psyclyx.nixos = {
      config = {
        roles.base.enable = true;
        users.psyc.workstation.enable = true;
      };

      boot = {
        # TODO: consider removing plymouth entirely
        # frequently breaks when i twiddle nvidia settings, tty unlock occasionally
        # echos keystrokes instead of *, seems occasionally unhappy when decryption prompts
        # straddle stage1/stage2
        # plymouth.enable = lib.mkDefault true;
      };

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
