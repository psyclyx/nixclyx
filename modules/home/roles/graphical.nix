{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;

  common = {
    home.packages = with pkgs; [
      psyclyx.upscale-image
    ];
  };

  linux = {
    home.packages = with pkgs; [
      firefox-bin
      signal-desktop-bin
    ];
    psyclyx = {
      programs = {
        alacritty.enable = lib.mkDefault true;
        sway.enable = lib.mkDefault true;
        waybar.enable = lib.mkDefault true;
        xdg.enable = lib.mkDefault true;
      };
    };
  };

  darwin = {
    psyclyx.programs.kitty.enable = lib.mkDefault true;
  };

  cfgEnabled = config.psyclyx.roles.graphical;
in
{
  options.psyclyx.roles.graphical = lib.mkEnableOption "graphical session programs/config";

  config = lib.mkIf cfgEnabled (
    lib.mkMerge [
      common
      (if isLinux then linux else { })
      (if isDarwin then darwin else { })
    ]
  );
}
