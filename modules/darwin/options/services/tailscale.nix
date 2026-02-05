{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "services" "tailscale"];
  description = "Tailscale VPN";
  config = _: {
    environment.systemPackages = [pkgs.tailscale];
    services.tailscale.enable = true;
  };
} args
