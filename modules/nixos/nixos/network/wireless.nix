{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.network.wireless;
in
{
  options = {
    psyclyx.nixos.network.wireless = {
      enable = lib.mkEnableOption "wireless network support";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wireless.iwd = {
      enable = true;
      settings.Settings.AutoConnect = true;
    };
  };
}
