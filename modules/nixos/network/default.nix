{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.psyclyx.network;
in
{
  options = {
    psyclyx.network = {
      enable = lib.mkEnableOption "network config";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.useNetworkd = true;
    systemd.network = {
      enable = true;
      wait-online.anyInterface = true;
    };
  };
}
