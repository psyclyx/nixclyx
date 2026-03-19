{
  path = ["psyclyx" "common" "system" "stylix"];
  description = "stylix configuration";
  options = {lib, ...}: {
    base24Gen = lib.mkOption {
      description = "replace stylix's palette generator with base24-gen";
      default = true;
      type = lib.types.bool;
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    nixclyx,
    ...
  }: let
    base24-gen-palette-generator = let
      base24-gen = lib.getExe pkgs.psyclyx."base24-gen";
      yq = lib.getExe pkgs.yq;
    in
      pkgs.writeShellScriptBin "palette-generator" ''
        ${base24-gen} --mode "$1" "$2" | ${yq} > "$3"
      '';
  in {
    stylix = {
      enable = true;

      polarity = lib.mkIf cfg.base24Gen (lib.mkDefault "dark");
      paletteGenerator = lib.mkIf cfg.base24Gen base24-gen-palette-generator;

      image = lib.mkDefault "${pkgs.nixos-artwork.wallpapers.catppuccin-macchiato}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-macchiato.png";
      base16Scheme = lib.mkDefault nixclyx.assets.palettes."nixos-wallpaper-catppuccin-macchiato.yaml";

      opacity = {
        applications = lib.mkDefault 0.92;
        desktop = lib.mkDefault 0.88;
        terminal = lib.mkDefault 0.9;
        popups = lib.mkDefault 0.95;
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
}
