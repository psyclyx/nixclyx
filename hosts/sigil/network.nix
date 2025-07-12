{
  config,
  inputs,
  pkgs,
  ...
}:
{
  networking = {
    useNetworkd = true;
  };
  systemd = {
    network = {
      enable = true;
      config = {
        networkConfig = {
          ManageForeignRoutingPolicyRules = false;
          ManageForeignRoutes = false;
        };
      };
      wait-online = {
        anyInterface = true;
      };
      networks = {
        "40-enp6s0" = {
          matchConfig = {
            Name = "enp6s0";
          };
          linkConfig = {
            RequiredForOnline = "routable";
          };
          dns = [
            "1.1.1.1"
            "2606:4700:4700::1111"
            "8.8.8.8"
          ];
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = false;
          };
        };
      };
    };
  };
}
