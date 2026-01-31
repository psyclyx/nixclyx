{ ... }:
{
  config = {
    systemd = {
      network = {
        netdevs = {
          "10-bond0" = {
            netdevConfig = {
              Name = "bond0";
              Kind = "bond";
            };

            bondConfig = {
              Mode = "802.3ad";
              LACPTransmitRate = "slow";
              TransmitHashPolicy = "layer3+4";
            };
          };
        };

        networks = {
          "30-bond0-ports" = {
            matchConfig.Name = "enp5s0f?";
            networkConfig.Bond = "bond0";
          };
          "40-bond0" = {
            matchConfig.Name = "bond0";
            networkConfig.DHCP = true;
          };
        };
      };
    };
  };
}
