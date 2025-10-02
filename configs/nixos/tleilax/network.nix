{ pkgs, ... }:
let
  prefix6 = "2606:7940:32:26::";
  prefix4 = "199.255.18.171";
in
{
  networking = {
    useNetworkd = true;
    useDHCP = false;
  };

  systemd = {
    network = {
      enable = true;
      config.networkConfig = {
        ManageForeignRoutingPolicyRules = false;
        ManageForeignRoutes = false;
      };

      wait-online.anyInterface = true;

      links = {
        "04-bond" = {
          matchConfig = {
            Type = "bond";
          };
          linkConfig = {
            MACAddressPolicy = "none";
          };
        };
      };

      netdevs = {
        "10-bond0" = {
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
          matchConfig = {
            Name = "ens1f0np0";
            PermanentMACAddress = "6c:b3:11:95:03:88";
          };
          networkConfig.Bond = "bond0";
        };

        "30-ens1f1np1" = {
          matchConfig = {
            Name = "ens1f1np1";
            PermanentMACAddress = "6c:b3:11:95:03:89";
          };
          networkConfig.Bond = "bond0";
        };

        "40-bond0" = {
          matchConfig.Name = "bond0";
          linkConfig = {
            MACAddress = "6c:b3:11:95:03:88";
            RequiredForOnline = "routable";
          };
          address = [
            "${prefix4}/32"
            "${prefix6}10/120"
          ];
          gateway = [ "${prefix6}1" ];
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
            IPv6AcceptRA = false;
            IPv6Forwarding = true;
          };
        };
      };
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8080 ];
  };
}
