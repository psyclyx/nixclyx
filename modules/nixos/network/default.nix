{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.psyclyx.network;
  network =
    { name, ... }:
    {
      options = {
        interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ name ];
        };
        enableDHCP = lib.mkEnableOption "DHCP";
        requiredForOnline = lib.mkEnableOption "participation in wait-online.target";
      };
    };
in
{
  options = {
    psyclyx.network = {
      enable = lib.mkEnableOption "network config";
      networks = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule network); };
      MDNS = lib.mkEnableOption "MDNS for .local resolution and service discovery";
      waitOnline = lib.mkEnableOption "wait-online.target blocks on interfaces coming online";
      wireless = lib.mkEnableOption "wireless network connections";
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      useNetworkd = true;
      wireless = lib.mkIf cfg.wireless {
        iwd = {
          enable = true;
          settings.Settings.AutoConnect = true;
        };
      };
    };

    psyclyx.services.avahi.enable = cfg.MDNS;

    systemd.network = {
      enable = true;

      wait-online = {
        enable = cfg.waitOnline;
        anyInterface = true;
      };

      networks = lib.mapAttrs' (
        name: network:
        lib.nameValuePair "40-${name}" {
          matchConfig.Name = name;
          linkConfig.RequiredForOnline = lib.mkIf network.requiredForOnline "routable";
          networkConfig.DHCP = lib.mkIf network.enableDHCP true;
        }
      ) cfg.networks;
    };
  };
}
