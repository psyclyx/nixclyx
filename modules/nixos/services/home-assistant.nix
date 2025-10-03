{ config, lib, ... }:
let
  cfg = config.psyclyx.services.home-assistant;
  port = config.psyclyx.network.ports.home-assistant;
in
{
  options = {
    psyclyx = {
      services = {
        home-assistant = {
          enable = lib.mkEnableOption "Enables Home Assistant, with @psyclyx's config";
        };
      };
      network = {
        ports = {
          home-assistant = lib.mkOption {
            type = lib.types.port;
            default = 8123;
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      firewall = {
        allowedTCPPorts = [ port ];
      };
    };

    services = {
      home-assistant = {
        enable = true;
        extraComponents = [
          "esphome"
          "met"
          "radio_browser"
          "zha"
          "ios"
        ];
        config = {
          http = {
            server_port = port;
          };
          default_config = { };
        };
      };
    };
  };
}
