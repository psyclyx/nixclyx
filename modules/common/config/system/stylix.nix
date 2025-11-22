{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) stylix;
  inherit (pkgs) stdenv;
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
    pkgs.writeShellScriptBin "flavours-palette-generator" ''
      ${flavours} generate "$1" "$2" --stdout | ${yq} > "$3"
    '';

  stylixModule =
    if stdenv.isNixos then
      stylix.nixosModules.stylix
    else if stdenv.isDarwin then
      stylix.darwinModules.stylix
    else
      builtins.throw "unsupported env";

  cfg = config.psyclyx.system.stylix;
in
{

  imports = [ stylixModule ];

  options = {
    psyclyx.system.stylix = {
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

      paletteGenerator = mkIf cfg.flavours (mkForce flavours-palette-generator);

      image = mkDefault "${pkgs.nixos-artwork.wallpapers.catppuccin-macchiato}/share/backgrounds/nixos/nixos-wallpaper-catppucin-macchiato.png";

      opacity = {
        applications = mkDefault 0.85;
        desktop = mkDefault 0.75;
        terminal = mkDefault 0.8;
        popups = mkDefault 0.9;
      };

      fonts = {
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
