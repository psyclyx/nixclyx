{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.base;
in
{
  options = {
    psyclyx.roles.base = {
      enable = lib.mkEnableOption "role for baseline darwin config";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      programs = {
        zsh.enable = lib.mkDefault true;
      };
      system = {
        home-manager.enable = lib.mkDefault true;
        homebrew.enable = lib.mkDefault true;
        nix.enable = lib.mkDefault true;
        security.enable = lib.mkDefault true;
        settings.enable = lib.mkDefault true;
      };
    };
  };
}
