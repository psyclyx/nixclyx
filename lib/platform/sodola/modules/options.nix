# Sodola platform — option schema (generic, egregore-unaware).
#
# Mirrors the tool's document: network, auth, per-port rows, the VLAN
# table, and a couple of device hints. A fleet projection sets these;
# the render module emits the hex `.bin`.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in {
  options.system.build = mkOption { type = types.attrsOf types.package; default = { }; };
  options.sodolaJson = mkOption { type = types.anything; default = { }; internal = true; };
  options.sodola = mkOption {
    default = { };
    type = types.submodule {
      options = {
        model = mkOption { type = types.str; default = ""; };
        password = mkOption { type = types.str; default = "admin"; };
        auth = mkOption {
          type = types.submodule { options.username = mkOption { type = types.str; default = "admin"; }; };
          default = { };
        };
        network = mkOption {
          type = types.submodule {
            options = {
              ip = mkOption { type = types.str; default = ""; };
              netmask = mkOption { type = types.str; default = ""; };
              gateway = mkOption { type = types.str; default = ""; };
            };
          };
          default = { };
        };
        ports = mkOption {
          type = types.listOf (types.submodule {
            options = {
              mode = mkOption { type = types.str; default = "trunk"; };
              nativeVlan = mkOption { type = types.int; default = 1; };
              speed = mkOption { type = types.str; default = "auto"; };
            };
          });
          default = [ ];
        };
        vlans = mkOption {
          type = types.listOf (types.submodule {
            options = {
              id = mkOption { type = types.int; };
              members = mkOption { type = types.listOf types.int; default = [ ]; };
              name = mkOption { type = types.str; default = ""; };
            };
          });
          default = [ ];
        };
        mgmtVlanHint = mkOption { type = types.int; default = 1; };
        igmpEnabled = mkOption { type = types.bool; default = false; };
      };
    };
  };
}
