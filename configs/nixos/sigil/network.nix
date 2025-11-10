{ config, lib, ... }:
let
  inherit (lib) ;

  cfg = config.psyclyx.hosts.sigil;
in
{
  config = {
    services.resolved.enable = true;

    networking.useNetworkd = true;

    systemd.network = {
      wait-online = {
        enable = true;
        anyInterface = true;
      };

      networks = {
        enp5s0f1 = {
          linkConfig.RequiredForOnline = true;
          networkConfig = {
            DHCP = true;
            UseDomains = true;
          };
        };
      };
    };
  };
}
