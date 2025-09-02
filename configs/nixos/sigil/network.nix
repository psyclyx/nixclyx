{
  pkgs,
  lib,
  ...
}:
{
  networking = {
    useNetworkd = true;
  };

  systemd = {
    network = {
      enable = true;
      wait-online.anyInterface = true;
      networks."40-enp5s0" = {
        matchConfig.Name = "enp5s0";
        linkConfig.RequiredForOnline = "routable";
        dns = [
          "1.1.1.1"
          "2606:4700:4700::1111"
          "8.8.8.8"
        ];
        networkConfig = {
          IPv6AcceptRA = true;
          DHCP = "ipv4";
        };
      };
    };
    services.disable-eee-enp5s0 = {
      description = "Disable EEE to prevent occasional r8619 connection dropouts (TP-Link TX-201 with RealTek RTL8125 chipset)";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${lib.getExe pkgs.ethtool} --set-eee enp5s0 eee off";
      };
      wantedBy = [ "network-pre.target" ];
    };
  };
}
