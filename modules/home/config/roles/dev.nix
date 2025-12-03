{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.dev;
in
{
  options = {
    psyclyx.roles.dev = {
      enable = lib.mkEnableOption "Development tools and configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      programs = {
        fastfetch.enable = lib.mkDefault true;
        git.enable = lib.mkDefault true;
        helix.enable = lib.mkDefault true;
        neovim.enable = lib.mkDefault true;
      };
    };
  };
}
