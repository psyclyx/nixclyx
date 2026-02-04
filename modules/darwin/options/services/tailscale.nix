{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.darwin.services.tailscale;
in {
  options.psyclyx.darwin.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.tailscale];
    services.tailscale = {
      enable = true;
    };
  };
}
