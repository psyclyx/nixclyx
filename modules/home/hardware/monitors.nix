{
  path = ["psyclyx" "home" "hardware" "monitors"];
  gate = "always";
  extraOptions = {lib, ...}: let
    inherit (lib) mkOption types;
    monitorType = types.submodule (
      {name, ...}: {
        options = {
          identifier = mkOption {
            type = types.str;
            default = name;
          };
          connector = mkOption {
            type = types.str;
            default = "";
          };
          mode = mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  width = mkOption {type = types.int;};
                  height = mkOption {type = types.int;};
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
          colorProfile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Display ICC profile to load for this monitor (calibrated SDR),
              applied via set-output-icc over the psyclyx_color_management_v1
              protocol. Keyed to the monitor identity, so it follows the panel
              across connectors.
            '';
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
            default = {};
          };
        };
      }
    );
  in {
    psyclyx.home.hardware.monitors = mkOption {
      type = types.attrsOf monitorType;
      default = {};
    };
  };
}
