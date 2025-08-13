{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.stylix;
in
{
  # Nonstandard `enable` behavior:
  # Disabling stylix itself would cause the issue mentioned at
  # https://nix-community.github.io/stylix/tricks.html#completely-disabling-some-stylix-targets
  # Disabling autoEnable accomplishes the same thing in a config that
  # isn't otherwise using stylix.
  options.psyclyx.stylix = {
    enable = lib.mkEnableOption "stylix";
    image = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "path to wallpaper";
    };
    base16Scheme = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "path to base16 theme";
    };
    baseFontSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Base font size";
    };
  };
  config =
    let
      fallbackImage = config.lib.stylix.pixel "base00";
      fallbackScheme = "${pkgs.base16-schemes}/share/themes/catppuccin-macchiato.yaml";
      haveImage = cfg.image != null;
      haveScheme = cfg.base16Scheme != null;
      image = if haveImage then cfg.image else fallbackImage;
      base16Scheme =
        if haveScheme then cfg.base16Scheme else (if haveImage then null else fallbackScheme);
    in
    {
      stylix = {
        enable = true;
        inherit image;
        base16Scheme = lib.mkIf (base16Scheme != null) base16Scheme;
        autoEnable = cfg.enable;
        opacity = {
          applications = 0.8;
          desktop = 0.7;
          terminal = 0.8;
          popups = 0.9;
        };
        fonts = {
          sizes = {
            desktop = cfg.baseFontSize - 2;
            applications = cfg.baseFontSize;
            terminal = cfg.baseFontSize;
            popups = cfg.baseFontSize;
          };
          serif = {
            package = pkgs.nerd-fonts.noto;
            name = "NotoSerif Nerd Font";
          };
          sansSerif = {
            package = pkgs.nerd-fonts.noto;
            name = "NotoSans Nerd Font";
          };
          monospace = {
            package = pkgs.aporetic;
            name = "Aporetic Sans Mono";
          };
          emoji = {
            package = pkgs.noto-fonts-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    };
}
