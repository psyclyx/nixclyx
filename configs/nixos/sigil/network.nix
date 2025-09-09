{
  pkgs,
  lib,
  ...
}:
{
  systemd = {
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
