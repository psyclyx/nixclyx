{
  path = ["psyclyx" "darwin" "services" "tailscale"];
  description = "Tailscale VPN";
  config = {pkgs, ...}: {
    environment.systemPackages = [pkgs.tailscale];
    services.tailscale.enable = true;
  };
}
