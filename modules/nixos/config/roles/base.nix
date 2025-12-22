{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.roles.base;
in

{
  options = {
    psyclyx.roles.base = {
      enable = mkEnableOption "role for baseline config, likely applicable to all hosts";
    };
  };

  config = mkIf cfg.enable {
    psyclyx = {
      boot = {
        systemd-boot.enable = lib.mkDefault true;
        systemd-initrd.enable = lib.mkDefault true;
      };

      hardware = {
        tune = {
          hdd.enable = lib.mkDefault true;
          ssd.enable = lib.mkDefault true;
          nvme.enable = lib.mkDefault true;
        };
      };

      programs = {
        zsh.enable = mkDefault true;
      };

      system = {
        containers.enable = mkDefault false;
        documentation.enable = mkDefault true;
        home-manager.enable = mkDefault true;
        locale.enable = mkDefault true;
        nix.enable = mkDefault true;
        nixpkgs.enable = mkDefault true;
        stylix.enable = mkDefault true;
        swap.enable = mkDefault true;
        timezone.enable = mkDefault true;
      };
    };
  };
}
