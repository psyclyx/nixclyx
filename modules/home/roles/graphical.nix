{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfgEnabled = config.psyclyx.roles.graphical;
in
{
  options.psyclyx.roles.graphical = lib.mkEnableOption "graphical session programs/config";

  config = lib.mkIf cfgEnabled (
    lib.mkMerge [
      {
        home.packages =
          (with pkgs; [ fastfetch ])
          ++ (with inputs.self.packages."${pkgs.system}"; [
            upscale-image
            print256colors
          ]);
      }
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
