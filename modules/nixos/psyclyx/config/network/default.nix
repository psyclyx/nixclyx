{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.network;
in
{
  imports = [ ./dns ];

  options = {
    psyclyx.network = {
      enable = lib.mkEnableOption "common network settings";
      wireless = lib.mkEnableOption "wireless network support";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      useNetworkd = true;

      wireless.iwd = lib.mkIf cfg.wireless {
        enable = true;
        settings.Settings.AutoConnect = true;
      };
    };

    systemd.network = {
      enable = true;
      wait-online.enable = lib.mkDefault false;
    };
  };
}
