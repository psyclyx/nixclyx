# Global configuration — cross-cutting values used by type modules
# and projections. Not entities — context.
{ lib, ... }: {
  options = {
    conventions = lib.mkOption {
      type = lib.types.submodule {
        options = {
          gatewayOffset = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Host offset for gateway address within each subnet.";
          };
          transitVlan = lib.mkOption {
            type = lib.types.int;
            default = 250;
            description = "VLAN ID for WAN transit.";
          };
          adminSshKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "SSH public keys for administrative access.";
          };
        };
      };
      default = {};
    };

    domains = lib.mkOption {
      type = lib.types.submodule {
        options = {
          internal = lib.mkOption { type = lib.types.str; default = ""; };
          public = lib.mkOption { type = lib.types.str; default = ""; };
          home = lib.mkOption { type = lib.types.str; default = ""; };
        };
      };
      default = {};
    };

    ipv6UlaPrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "IPv6 ULA prefix (e.g. fd9a:e830:4b1e).";
    };

    overlay = lib.mkOption {
      description = "VPN overlay network configuration.";
      type = lib.types.submodule {
        options = {
          subnet = lib.mkOption { type = lib.types.str; default = ""; };
          port = lib.mkOption { type = lib.types.int; default = 51820; };
          hub = lib.mkOption { type = lib.types.str; default = ""; };
        };
      };
      default = {};
    };
  };
}
