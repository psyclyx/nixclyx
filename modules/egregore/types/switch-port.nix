# Shared port submodule and helpers for switch entity types.
#
# Port classification by field presence:
#   { vlan = N; }      → access (untagged)
#   { vlans = [...]; } → trunk (tagged)
#   { }                → unused (disabled)
#
# Usage:
#   let portDef = import ./switch-port.nix { inherit lib; };
#   in {
#     type = lib.types.attrsOf (lib.types.submodule portDef.module);
#     portDef.portType somePort   # → "access" | "trunk" | "unused"
#     portDef.portLabel somePort  # → human description
#   }
#
{ lib }:
{
  # Submodule for use in types.attrsOf (types.submodule portDef.module)
  module = {
    options = {
      vlan = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      vlans = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
      };
      meta = lib.mkOption {
        type = lib.types.submodule {
          options = {
            host = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            peer = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            description = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          };
        };
        default = {};
      };
    };
  };

  portType = port:
    if port.vlan != null then "access"
    else if port.vlans != [] then "trunk"
    else "unused";

  portLabel = port: let
    meta = port.meta;
  in
    if meta.host != null && meta.description != null then "${meta.host} ${meta.description}"
    else if meta.host != null then meta.host
    else if meta.description != null then meta.description
    else if meta.peer != null then "trunk to ${meta.peer}"
    else if port.vlan != null then "access VLAN ${toString port.vlan}"
    else if port.vlans != [] then "trunk"
    else "unused";
}
