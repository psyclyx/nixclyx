{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.roles.graphical;
in {
  options = {
    psyclyx.nixos.roles.graphical = {
      enable = lib.mkEnableOption "role for hosts intended to be used primarily through graphical sessions";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_zen;
    };

    psyclyx = {
      nixos = {
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
  };
}
