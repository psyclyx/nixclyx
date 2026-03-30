# Entity type: MikroTik RouterOS switch.
{ lib, egregorLib, config, ... }:
let
  portDef = import ../lib/switch-port.nix { inherit lib; };
in
egregorLib.mkType {
  name = "routeros";
  topConfig = config;
  description = "MikroTik RouterOS managed switch.";

  options = {
    model = lib.mkOption { type = lib.types.str; default = ""; };
    identity = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    addresses = lib.mkOption {
      type = lib.types.submodule {
        options.mgmt = lib.mkOption {
          type = lib.types.submodule {
            options.ipv4 = lib.mkOption { type = lib.types.str; };
          };
        };
      };
    };
    ports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule portDef.module);
      default = {};
    };
    bonds = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mode = lib.mkOption { type = lib.types.str; };
          slaves = lib.mkOption { type = lib.types.listOf lib.types.str; };
          lacpMode = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      });
      default = {};
    };
  };

  attrs = name: entity: _top: let
    r = entity.routeros;
    active = lib.filterAttrs (_: p: portDef.portType p != "unused") r.ports;
  in {
    address = r.addresses.mgmt.ipv4;
    label = "${if r.identity != null then r.identity else name} (${r.model})";
    platform = "routeros";
    model = r.model;
    portCount = builtins.length (builtins.attrNames r.ports);
    activePortCount = builtins.length (builtins.attrNames active);
  };
}
