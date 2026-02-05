{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "roles" "graphical"];
  description = "Graphical session programs and configuration";
  config = _:
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
              sway.enable = lib.mkDefault true;
            };
            xdg.enable = lib.mkDefault true;
          };
        };
      })

      (lib.mkIf pkgs.stdenv.isDarwin {
        psyclyx.home.programs.kitty.enable = lib.mkDefault true;
      })
    ];
} args
