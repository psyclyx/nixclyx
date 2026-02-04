{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.config.roles.base;
in {
  options.psyclyx.darwin.config.roles.base = {
    enable = lib.mkEnableOption "base darwin role";
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      common.system.nixpkgs.enable = lib.mkDefault true;

      darwin = {
        programs.zsh.enable = lib.mkDefault true;

        system = {
          home-manager.enable = lib.mkDefault true;
          homebrew.enable = lib.mkDefault true;
          nix.enable = lib.mkDefault true;
          nixpkgs.enable = lib.mkDefault true;
          security.enable = lib.mkDefault true;
          settings.enable = lib.mkDefault true;
          stylix.enable = lib.mkDefault true;
        };
      };
    };
  };
}
