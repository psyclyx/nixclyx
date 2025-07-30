{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfgEnabled = config.psyclyx.roles.sway;
in
{
  options.psyclyx.roles.sway = lib.mkEnableOption "sway, etc";
  config = lib.mkIf cfgEnabled {
    assertions = [ (lib.hm.assertions.assertPlatform "psyclyx.roles.sway" pkgs lib.platforms.linux) ];
    psyclyx = {
      programs.sway.enable = lib.mkDefault true;
      programs.waybar.enable = lib.mkDefault true;
    };
  };
}
