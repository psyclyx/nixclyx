{ ... }:
let
  prefix6 = "2606:7940:32:26::";
  prefix4 = "199.255.18.171";
in
{
  systemd = {
    network = {
      config.networkConfig = {
        ManageForeignRoutingPolicyRules = false;
        ManageForeignRoutes = false;
      };

      wait-online.enable = true;

      netdevs = {
        "10-eno1".enable = false;
        "10-eno2".enable = false;

        "20-bond0" = {
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
        "30-ens1f0np0" = {
          matchConfig.Name = "ens1f0np0";
          networkConfig.Bond = "bond0";
        };

        "30-ens1f1np1" = {
          matchConfig.Name = "ens1f1np1";
          networkConfig.Bond = "bond0";
        };

        "40-bond0" = {
          matchConfig.Name = "bond0";
          linkConfig.RequiredForOnline = "routable";

          address = [
            "${prefix4}/32"
            "${prefix6}10/120"
          ];

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

          networkConfig = {
            DHCP = false;
            IPv6AcceptRA = false;
            IPv6Forwarding = true;
          };
        };
      };
    };
  };
}
