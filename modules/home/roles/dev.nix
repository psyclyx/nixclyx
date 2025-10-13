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
    home.packages = with pkgs; [
      just
      just-formatter

      nixd
      nixfmt-rfc-style

      temurin-bin-25

      zig
      zls
    ];
    psyclyx = {
      programs = {
        emacs.enable = lib.mkDefault true;
        fastfetch.enable = lib.mkDefault true;
        git.enable = lib.mkDefault true;
      };
    };
  };
}
