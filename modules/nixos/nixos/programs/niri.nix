{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.programs.niri;
in
{
  options = {
    psyclyx.nixos.programs.niri = {
      enable = lib.mkEnableOption "Scrolling Wayland compositor";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = pkgs.niri;
    };
    environment.systemPackages = [ pkgs.xwayland-satellite ];
  };
}
