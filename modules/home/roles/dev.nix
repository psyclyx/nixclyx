{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfgEnabled = config.psyclyx.roles.dev;
in
{
  options.psyclyx.roles.dev = lib.mkEnableOption "dev tools/config";

  config = lib.mkIf cfgEnabled {
    home.packages = with pkgs; [
      zig
      zls
      nixfmt-rfc-style
      nixd
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
