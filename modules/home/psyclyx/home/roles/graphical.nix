{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.home.roles.graphical;
in
{
  options = {
    psyclyx.home.roles.graphical = {
      enable = lib.mkEnableOption "Graphical session programs and configuration";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf pkgs.stdenv.isLinux {
        home.packages = [
          pkgs.element-desktop
          pkgs.firefox-bin
          pkgs.signal-desktop-bin
        ];

        psyclyx = {
          home = {
            programs = {
              alacritty.enable = lib.mkDefault true;
              ghostty = {
                enable = lib.mkDefault true;
                defaultTerminal = lib.mkDefault true;
              };
              niri.enable = lib.mkDefault true;
              sway.enable = lib.mkDefault true;
            };
            xdg.enable = lib.mkDefault true;
          };
        };
      })

      (lib.mkIf pkgs.stdenv.isDarwin {
        psyclyx.home.programs.kitty.enable = lib.mkDefault true;
      })
    ]
  );
}
