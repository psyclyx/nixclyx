{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkIf
    ;
  inherit (pkgs.stdenv.hostPlatform) system;

  inherit (config.psyclyx.home.deps) astal;

  cfg = config.psyclyx.home.programs.ags;
in {
  options = {
    psyclyx.home.programs.ags = {
      enable = mkEnableOption "AGS (Aylur's GTK Shell)";
    };
  };

  config = mkIf cfg.enable {
    programs.ags = {
      enable = true;
      systemd.enable = true;
      configDir = ./shell;
      extraPackages = let
        astalPkgs = astal.packages.${system};
      in [
        astalPkgs.tray
        astalPkgs.battery
        astalPkgs.wireplumber
        astalPkgs.network
        astalPkgs.apps
        astalPkgs.powerprofiles
        pkgs.swayfx
      ];
    };
  };
}
