{ lib, ... }:
let
  inherit (lib) mkOption types;

  monitorType = types.submodule (
    { name, ... }:
    {
      options = {
        identifier = mkOption {
          type = types.str;
          default = name;
        };
        connector = mkOption {
          type = types.str;
        };
        mode = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                width = mkOption { type = types.int; };
                height = mkOption { type = types.int; };
                refresh = mkOption {
                  type = types.nullOr types.number;
                  default = null;
                };
              };
            }
          );
          default = null;
        };
        scale = mkOption {
          type = types.number;
          default = 1.0;
        };
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        position = mkOption {
          type = types.submodule {
            options = {
              x = mkOption {
                type = types.int;
                default = 0;
              };
              y = mkOption {
                type = types.int;
                default = 0;
              };
            };
          };
          default = { };
        };
      };
    }
  );
in
{
  options.psyclyx.home.hardware.monitors = mkOption {
    type = types.attrsOf monitorType;
    default = { };
  };
}
