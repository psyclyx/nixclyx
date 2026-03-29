# Entity type: host (a machine with network addresses).
{ lib, egregorLib, config, ... }:
egregorLib.mkType {
  name = "host";
  topConfig = config;
  description = "A machine with network addresses and hardware facts.";

  options = {
    addresses = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          ipv4 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          ipv6 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      });
      default = {};
    };
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.device = lib.mkOption { type = lib.types.str; };
      });
      default = {};
    };
    mac = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };
    wireguard = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          publicKey = lib.mkOption { type = lib.types.str; };
          endpoint = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          exportedRoutes = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
          allowedNetworks = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        };
      });
      default = null;
    };
    roles = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
    sshPort = lib.mkOption { type = lib.types.int; default = 22; };
    publicIPv4 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    publicIPv6 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    hardware = lib.mkOption {
      type = lib.types.submodule {
        options.tpm = lib.mkOption { type = lib.types.bool; default = false; };
      };
      default = {};
    };
    exporters = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          port = lib.mkOption { type = lib.types.int; };
          networks = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        };
      });
      default = {};
    };
  };

  attrs = _name: entity: _top: let
    h = entity.host;
    vpn = h.addresses.vpn or null;
  in {
    address = if vpn != null then vpn.ipv4 else null;
    roles = h.roles;
    sshPort = h.sshPort;
    hasTpm = h.hardware.tpm;
    label = builtins.concatStringsSep ", " h.roles;
  };
}
