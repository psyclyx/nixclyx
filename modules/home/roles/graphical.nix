{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = {
    home.packages = with pkgs; [
      psyclyx.upscale-image
    ];
  };

  linux =
    { lib, pkgs, ... }:
    {
      config = lib.mkIf pkgs.stdenv.isLinux {
      };
    };

  darwin =
    { lib, pkgs, ... }:
    {
      config = lib.mkIf pkgs.stdenv.isDarwin {
        psyclyx.programs.kitty.enable = lib.mkDefault true;
      };
    };

  cfgEnabled = config.psyclyx.roles.graphical;
in
{
  options.psyclyx.roles.graphical = lib.mkEnableOption "graphical session programs/config";

  config = lib.mkIf cfgEnabled (

    lib.mkMerge [
      { home.packages = with pkgs; [ psyclyx.upscale-image ]; }
      (lib.mkIf pkgs.stdenv.isLinux {
        home.packages = with pkgs; [
          firefox-bin
          signal-desktop-bin
        ];
        psyclyx = {
          programs = {
            alacritty.enable = lib.mkDefault true;
            sway.enable = lib.mkDefault true;
            waybar.enable = lib.mkDefault true;
          };
          xdg.enable = lib.mkDefault true;
        };
      })
      (lib.mkIf pkgs.stdenv.isDarwin {
        psyclyx.programs.kitty.enable = lib.mkDefault true;
      })
    ]
  );
}
