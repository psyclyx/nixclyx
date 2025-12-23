{
  moduleGroup ? "common",
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkOption
    types
    ;

  flavours-palette-generator =
    let
      flavours = getExe pkgs.flavours;
      yq = getExe pkgs.yq;
    in
    pkgs.writeShellScriptBin "palette-generator" ''
      ${flavours} generate "$1" "$2" --stdout | ${yq} > "$3"
    '';

  cfg = config.psyclyx.${moduleGroup}.system.stylix;
in
{
  options = {
    psyclyx.${moduleGroup}.system.stylix = {
      enable = mkEnableOption "stylix configuration";

      flavours = mkOption {
        description = "replace stylix's palette generator with flavours";
        default = true;
        type = types.bool;
      };
    };
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;

      polarity = mkIf cfg.flavours (mkDefault "light");
      paletteGenerator = mkIf cfg.flavours flavours-palette-generator;

      image = mkDefault "${pkgs.nixos-artwork.wallpapers.catppuccin-macchiato}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-macchiato.png";

      opacity = {
        applications = mkDefault 0.85;
        desktop = mkDefault 0.75;
        terminal = mkDefault 0.8;
        popups = mkDefault 0.9;
      };

      fonts = {
        sizes = {
          applications = mkDefault 16;
          desktop = mkDefault (config.stylix.fonts.sizes.applications - 2);
        };
        serif = mkDefault {
          package = pkgs.nerd-fonts.noto;
          name = "NotoSerif Nerd Font";
        };
        sansSerif = mkDefault {
          package = pkgs.nerd-fonts.noto;
          name = "NotoSans Nerd Font";
        };
        monospace = mkDefault {
          package = pkgs.aporetic;
          name = "Aporetic Sans Mono";
        };
        emoji = mkDefault {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
