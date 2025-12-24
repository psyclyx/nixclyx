{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;
  cfg = config.psyclyx.home.roles.dev;
in
{
  options = {
    psyclyx.home.roles.dev = {
      enable = mkEnableOption "Development tools and configuration";
    };
  };

  config = mkIf cfg.enable {
    psyclyx = {
      home = {
        programs = {
          fastfetch.enable = mkDefault true;
          git.enable = mkDefault true;
          helix.enable = mkDefault true;
          neovim.enable = mkDefault true;
        };
      };
    };
  };
}
