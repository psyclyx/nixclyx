{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.psyclyx.nixos.services.home-assistant;
  port = config.psyclyx.network.ports.home-assistant;
in
{
  options = {
    psyclyx = {
      network = {
        ports = {
          home-assistant = mkOption {
            type = types.port;
            default = 8123;
          };
        };
      };

      nixos.services.home-assistant = {
        enable = mkEnableOption "Enables Home Assistant, with @psyclyx's config";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ port ];
    services = {
      home-assistant = {
        enable = true;
        config = {
          default_config = { };
          http.server_port = port;
        };

        extraComponents = [
          "esphome"
          "met"
          "radio_browser"
          "zha"
          "ios"
        ];
      };
    };
  };
}
