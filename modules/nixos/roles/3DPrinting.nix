{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.roles."3DPrinting";
in
{
  options = {
    psyclyx.roles."3DPrinting" = {
      enable = mkEnableOption "CAD, printing software";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bambu-studio
      freecad-wayland
      orca-slicer
    ];
  };
}
