{config, ...}: {
  psyclyx.nixos.services.dhcp = {
    enable = true;
    interface = "enp1s0";
    pools = {
      main  = { network = "main";  ipv4Range = { start = "10.0.10.100";  end = "10.0.10.199"; }; };
      infra = { network = "infra"; ipv4Range = { start = "10.0.25.100";  end = "10.0.25.199"; }; };
      # prod/stage/data networks were retired in the 2026 storage-host
      # rework. The switch-routed VLANs (lab/storage) still ride DHCP
      # for reservation-based addressing — iyr serves on its L2-only
      # listener interface on each VLAN. The pool's free range is a
      # tiny non-fleet band; per-host reservations come from the
      # topology/network projection (managed hosts) and topology/pxe
      # projection (PXE boot-file).
      lab     = { network = "lab";     ipv4Range = { start = "10.0.210.240"; end = "10.0.210.254"; }; };
      storage = { network = "storage"; ipv4Range = { start = "10.0.200.240"; end = "10.0.200.254"; }; };
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
