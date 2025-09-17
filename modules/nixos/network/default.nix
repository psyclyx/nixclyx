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
        dns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
            "1.1.1.1"
            "1.0.0.1"
          ];
        };
        requiredForOnline = lib.mkEnableOption "participation in wait-online.target";
      };
    };
in
{
  options = {
    psyclyx.network = {
      enable = lib.mkEnableOption "network config";
      waitOnline = lib.mkEnableOption "wait-online.target blocks on interfaces coming online";
      networks = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule network); };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.useNetworkd = true;
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
          networkConfig.DHCP = lib.mkIf network.enableDHCP "ipv4";
          inherit (network) dns;
        }
      ) cfg.networks;
    };
  };
}
