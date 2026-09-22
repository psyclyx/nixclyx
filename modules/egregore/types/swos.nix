# Entity type: MikroTik SwOS switch.
{
  egregoreType = { lib, egregorLib, ... }: let
    portDef = import ../lib/switch-port.nix { inherit lib egregorLib; };
    portType = portDef.portType;
    portLabel = portDef.portLabel;

    # CSS326: 24 copper + 2 SFP+. Port order is the SwOS index order,
    # so this doubles as the index → name map the generator needs.
    hwPortNames =
      (map (i: "ether${toString i}") (lib.range 1 24))
      ++ ["sfp-sfpplus1" "sfp-sfpplus2"];
  in {
    name = "swos";
    description = "MikroTik SwOS managed switch.";

    options = {
      model = lib.mkOption { type = lib.types.str; default = ""; };
      identity = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      addresses = lib.mkOption {
        type = lib.types.submodule {
          options.mgmt = lib.mkOption {
            type = lib.types.submodule {
              options.ipv4 = lib.mkOption { type = lib.types.str; default = ""; };
            };
            default = {};
          };
        };
        default = {};
      };
      ports = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule portDef.module);
        default = {};
      };
      mgmtNetwork = lib.mkOption {
        type = lib.types.str;
        default = "mgmt";
        description = "Network entity providing management VLAN and gateway.";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "HTTP digest auth username.";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "HTTP digest auth password (empty = no password).";
      };
    };

    attrs = name: entity: _top: let
      s = entity.swos;
      active = lib.filterAttrs (_: p: portType p != "unused") s.ports;
    in {
      address = s.addresses.mgmt.ipv4;
      addresses = s.addresses;
      label = "${if s.identity != null then s.identity else name} (${s.model})";
      platform = "swos";
      model = s.model;
      portCount = builtins.length (builtins.attrNames s.ports);
      activePortCount = builtins.length (builtins.attrNames active);
      portNames = hwPortNames;
      links = portDef.links s.ports;
    };

    assertions = name: entity: top:
      portDef.linkAssertions name entity.swos.ports top;

  };
}
