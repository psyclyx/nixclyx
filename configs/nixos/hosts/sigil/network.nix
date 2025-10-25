{ config, lib, ... }:
let
in

{
  config = {
    psyclyx.services.avahi.enable = true;

    networking.useNetworkd = true;

    systemd.network = {
      wait-online = {
        enable = true;
        anyInterface = true;
      };

      networks = {
        enp6s0 = {
          linkConfig.RequiredForOnline = true;
          networkConfig = {
            DHCP = true;
            UseDomains = true;
            #SpeedMeter = true;
          };
        };
      };
    };
  };
}
