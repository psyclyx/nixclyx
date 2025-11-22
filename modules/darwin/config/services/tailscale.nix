{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.services.tailscale;
in
{
  options = {
    psyclyx.services.tailscale = {
      enable = lib.mkEnableOption "Tailscale VPN";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ tailscale ];
    services.tailscale = {
      enable = true;
    };
  };
}
