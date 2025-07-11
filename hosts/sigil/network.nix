{
  config,
  inputs,
  pkgs,
  ...
}:
{
  psyclyx.network.tailscale = {
    enable = true;
    exitNode = true;
  };
  services.resolved.enable = true;
  networking.useNetworkd = true;
  networking.networkmanager.enable = true;
  networking.useDHCP = false;
  networking.interfaces.enp6s0.useDHCP = true;
  networking.firewall.allowedTCPPorts = [
    8123
    3000
    51103
  ];
  networking.firewall.allowedUDPPorts = [
    51820
    6881
    3000
    51103
  ];
}
