# Entity type: Sodola web-managed switch.
{ lib, egregorLib, config, ... }:
let
  portDef = import ./switch-port.nix { inherit lib; };
in
egregorLib.mkType {
  name = "sodola";
  topConfig = config;
  description = "Sodola web-managed switch (binary config format).";

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
  };

  attrs = name: entity: _top: let
    s = entity.sodola;
    active = lib.filterAttrs (_: p: portDef.portType p != "unused") s.ports;
  in {
    address = s.addresses.mgmt.ipv4;
    label = "${if s.identity != null then s.identity else name} (${s.model})";
    platform = "sodola";
    model = s.model;
    portCount = builtins.length (builtins.attrNames s.ports);
    activePortCount = builtins.length (builtins.attrNames active);
  };
}
