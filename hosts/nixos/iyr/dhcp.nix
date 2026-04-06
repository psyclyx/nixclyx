{config, ...}: {
  psyclyx.nixos.services.dhcp = {
    enable = true;
    interface = "enp1s0";
    pools = {
      main  = { network = "main";  ipv4Range = { start = "10.0.10.100";  end = "10.0.10.199"; }; };
      infra = { network = "infra"; ipv4Range = { start = "10.0.25.100";  end = "10.0.25.199"; }; };
      prod  = { network = "prod";  ipv4Range = { start = "10.0.30.100";  end = "10.0.30.199"; }; };
      stage = { network = "stage"; ipv4Range = { start = "10.0.31.100";  end = "10.0.31.199"; }; };
      data  = { network = "data";  ipv4Range = { start = "10.0.50.100";  end = "10.0.50.199"; }; };
      guest = { network = "guest"; ipv4Range = { start = "10.0.100.10";  end = "10.0.100.249"; }; };
      iot   = { network = "iot";   ipv4Range = { start = "10.0.110.10";  end = "10.0.110.249"; }; };
      mgmt  = {
        network = "mgmt";
        ipv4Range = { start = "10.0.240.100"; end = "10.0.240.199"; };
        extraReservations = [
          { "hw-address" = "04:F4:1C:54:1D:8A"; "ip-address" = "10.0.240.2"; hostname = "mdf-agg01"; }
          { "hw-address" = "2C:C8:1B:00:82:89"; "ip-address" = "10.0.240.3"; hostname = "mdf-acc01"; }
          { "hw-address" = "94:18:82:74:f4:e0"; "ip-address" = "10.0.240.11"; hostname = "lab-1-ilo"; }
          { "hw-address" = "94:18:82:85:00:82"; "ip-address" = "10.0.240.12"; hostname = "lab-2-ilo"; }
          { "hw-address" = "14:02:EC:37:A1:48"; "ip-address" = "10.0.240.13"; hostname = "lab-3-ilo"; }
          { "hw-address" = "94:57:a5:51:20:62"; "ip-address" = "10.0.240.14"; hostname = "lab-4-ilo"; }
        ];
      };
    };
    extraDhcp4 = {
      dhcp-ddns.enable-updates = true;
      ddns-override-client-update = true;
      ddns-override-no-update = true;
      ddns-replace-client-name = "when-not-present";
      ddns-conflict-resolution-mode = "no-check-with-dhcid";
    };
    extraDhcp6 = {
      dhcp-ddns.enable-updates = true;
      ddns-override-client-update = true;
      ddns-override-no-update = true;
      ddns-replace-client-name = "when-not-present";
      ddns-conflict-resolution-mode = "no-check-with-dhcid";
      loggers = [{
        name = "kea-dhcp6";
        output_options = [{output = "stdout";}];
        severity = "WARN";
      }];
    };
  };
}
