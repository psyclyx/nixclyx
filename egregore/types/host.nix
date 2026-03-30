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
    deployAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH target for deployment. Null = not remotely deployable.";
    };
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

  attrs = name: entity: _top: let
    h = entity.host;
    vpn = h.addresses.vpn or null;
  in {
    address = if vpn != null then vpn.ipv4 else null;
    roles = h.roles;
    sshPort = h.sshPort;
    deployAddress = h.deployAddress;
    hasTpm = h.hardware.tpm;
    label = builtins.concatStringsSep ", " h.roles;
  };

  verbs = name: entity: _top: let
    h = entity.host;
    target = h.deployAddress;
    portFlag = lib.optionalString (h.sshPort != 22) "-p ${toString h.sshPort} ";
    sshDest = "root@${target}";
  in lib.optionalAttrs (target != null) {
    deploy = {
      description = "Copy a NixOS closure to this host and switch to it.";
      # impl expects $1 = store path to system closure
      impl = ''
        closure="''${1:?Usage: egregore verb ${name} deploy <closure-path>}"
        echo "Copying closure to ${target}..."
        NIX_SSHOPTS="${portFlag}" nix-copy-closure --to ${sshDest} "$closure"
        echo "Switching..."
        ssh ${portFlag}${sshDest} "$closure/bin/switch-to-configuration switch"
        echo "Deployed ${name}."
      '';
    };
  };
}
