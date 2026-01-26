{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.network.networkd;
in
{
  options = {
    psyclyx.nixos.network.networkd = {
      enable = lib.mkEnableOption "systemd-networkd";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.useNetworkd = true;
    systemd.network = {
      enable = true;
      wait-online.enable = lib.mkDefault false;
    };
  };
}
