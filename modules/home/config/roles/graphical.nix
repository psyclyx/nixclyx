{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    ;
  cfg = config.psyclyx.roles.graphical;
in
{
  options = {
    psyclyx.roles.graphical = {
      enable = mkEnableOption "Graphical session programs and configuration";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        element-desktop
        firefox-bin
        signal-desktop-bin
      ];
      psyclyx = {
        programs = {
          alacritty.enable = mkDefault true;
          ghostty = {
            enable = mkDefault true;
            defaultTerminal = mkDefault true;
          };
          sway.enable = mkDefault true;
        };
        xdg.enable = mkDefault true;
      };
    })
    (mkIf pkgs.stdenv.isDarwin {
      psyclyx.programs.kitty.enable = mkDefault true;
    })
  ]);
}
