{
  networking = {
    useNetworkd = true;
    wireless = {
      iwd = {
        enable = true;
        settings = {
          Settings = {
            AutoConnect = true;
          };
        };
      };
    };
  };
  systemd = {
    network = {
      enable = true;
      wait-online = {
        enable = false;
      };
      networks = {
        "40-wlan0" = {
          matchConfig = {
            Name = "wlan0";
          };
          dns = [
            "1.1.1.1"
            "2606:4700:4700::1111"
            "8.8.8.8"
          ];
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = true;
          };
        };
      };
    };
  };
}
