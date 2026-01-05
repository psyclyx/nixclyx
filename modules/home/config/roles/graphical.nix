{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.graphical;
in
{
  options = {
    psyclyx.roles.graphical = {
      enable = lib.mkEnableOption "Graphical session programs and configuration";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf pkgs.stdenv.isLinux {
        home.packages = with pkgs; [
          element-desktop
          firefox-bin
          signal-desktop-bin
        ];

        psyclyx = {
          programs = {
            alacritty.enable = lib.mkDefault true;
            ghostty = {
              enable = lib.mkDefault true;
              defaultTerminal = lib.mkDefault true;
            };

            sway.enable = lib.mkDefault true;
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
