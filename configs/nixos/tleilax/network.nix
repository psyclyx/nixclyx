{ ... }:
let
  prefix6 = "2606:7940:32:26::";
  prefix4 = "199.255.18.171";

  spaceSep = builtins.concatStringsSep " ";
in
{
  systemd = {
    network = {
      wait-online.enable = true;

      netdevs = {
        "10-create-bond0" = {
          netdevConfig = {
            Name = "bond0";
            Kind = "bond";
          };

          bondConfig = {
            Mode = "802.3ad";
            LACPTransmitRate = "fast";
            TransmitHashPolicy = "layer3+4";
          };
        };
      };

      networks = {
        "20-disable-enoX" = {
          matchConfig.Name = spaceSep [
            "eno0"
            "eno1"
          ];
          linkConfig.ActivationPolicy = "down";
        };

        "30-bond0-ports" = {
          matchConfig.Name = spaceSep [
            "ens1f0np0"
            "ens1f1np1"
          ];
          networkConfig.Bond = "bond0";
        };

        "40-bond0-controller" = {
          matchConfig.Name = "bond0";
          linkConfig.RequiredForOnline = "routable";

          address = [
            "${prefix4}/32"
            "${prefix6}10/120"
          ];

          networkConfig = {
            DHCP = false;
          };

          routes = [
            {
              Destination = "::/0";
              Gateway = "${prefix6}1";
            }
            {
              Destination = "0.0.0.0/0";
              Gateway = "${prefix6}1";
            }
          ];

          dns = [
            "2606:4700:4700::1111"
            "2001:4860:4860::8888"
          ];
        };
      };
    };
  };
}
