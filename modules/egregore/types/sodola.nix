# Entity type: Sodola web-managed switch.
{
  egregoreType = { lib, egregorLib, ... }: let
    portDef = import ../lib/switch-port.nix { inherit lib egregorLib; };
    portType = portDef.portType;

    # 8 copper + 1 SFP.
    hwPortNames = map (n: "port${toString n}") (lib.range 1 9);

    pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);
  in {
    name = "sodola";
    description = "Sodola web-managed switch (binary config format).";

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
        description = "Web UI auth username.";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Web UI auth password.";
      };
    };

    attrs = name: entity: _top: let
      s = entity.sodola;
      active = lib.filterAttrs (_: p: portType p != "unused") s.ports;
    in {
      address = s.addresses.mgmt.ipv4;
      addresses = s.addresses;
      label = "${if s.identity != null then s.identity else name} (${s.model})";
      platform = "sodola";
      model = s.model;
      portCount = builtins.length (builtins.attrNames s.ports);
      activePortCount = builtins.length (builtins.attrNames active);
      portNames = hwPortNames;
      links = portDef.links s.ports;
    };

    assertions = name: entity: top:
      portDef.linkAssertions name entity.sodola.ports top;

  };
}
