{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.network;
in
{
  options = {
    psyclyx.network = {
      enable = mkEnableOption "common network settings";
      wireless = mkEnableOption "wireless network support";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      useNetworkd = true;

      wireless.iwd = mkIf cfg.wireless {
        enable = true;
        settings.Settings.AutoConnect = true;
      };
    };

    systemd.network = {
      enable = true;
      wait-online.enable = mkDefault false;
    };
  };
}
