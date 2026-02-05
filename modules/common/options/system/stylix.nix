{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "common" "system" "stylix"];
  description = "stylix configuration";
  options = {
    flavours = lib.mkOption {
      description = "replace stylix's palette generator with flavours";
      default = true;
      type = lib.types.bool;
    };
  };
  config = {cfg, config, ...}: let
    flavours-palette-generator = let
      flavours = lib.getExe pkgs.flavours;
      yq = lib.getExe pkgs.yq;
    in
      pkgs.writeShellScriptBin "palette-generator" ''
        ${flavours} generate "$1" "$2" --stdout | ${yq} > "$3"
      '';
  in {
    stylix = {
      enable = true;

      polarity = lib.mkIf cfg.flavours (lib.mkDefault "light");
      paletteGenerator = lib.mkIf cfg.flavours flavours-palette-generator;

      image = lib.mkDefault "${pkgs.nixos-artwork.wallpapers.catppuccin-macchiato}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-macchiato.png";

      opacity = {
        applications = lib.mkDefault 0.85;
        desktop = lib.mkDefault 0.75;
        terminal = lib.mkDefault 0.8;
        popups = lib.mkDefault 0.9;
      };

      fonts = {
        sizes = {
          applications = lib.mkDefault 16;
          desktop = lib.mkDefault (config.stylix.fonts.sizes.applications - 2);
        };
        serif = lib.mkDefault {
          package = pkgs.nerd-fonts.noto;
          name = "NotoSerif Nerd Font";
        };
        sansSerif = lib.mkDefault {
          package = pkgs.nerd-fonts.noto;
          name = "NotoSans Nerd Font";
        };
        monospace = lib.mkDefault {
          package = pkgs.aporetic;
          name = "Aporetic Sans Mono";
        };
        emoji = lib.mkDefault {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
} args
