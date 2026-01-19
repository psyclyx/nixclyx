{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  inherit (pkgs.stdenv.hostPlatform) system;

  cfg = config.psyclyx.home.programs.ags;
in
{
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
      extraPackages =
        let
          astalPkgs = inputs.astal.packages.${system};
        in
        [
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
