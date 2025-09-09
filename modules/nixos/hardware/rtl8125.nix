{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.rtl8125;
in
{
  options = {
    psyclyx.hardware.rtl8125 = {
      disableEEEOn = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "list rtl8125 interfaces to disable EEE on, to reduce random dropped connections";
      };
    };
  };
  config = {
    systemd.services = lib.genAttrs' cfg.disableEEEOn (
      iface:
      lib.nameValuePair "rtl8125-disable-eee-${iface}" {
        description = "Hack to work around dropped connections on rtl8125 NIC";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = "${lib.getExe pkgs.ethtool} --set-eee enp5s0 eee off";
        };
        wantedBy = [ "network-pre.target" ];
      }
    );
  };
}
