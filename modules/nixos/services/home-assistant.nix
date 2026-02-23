{
  path = ["psyclyx" "nixos" "services" "home-assistant"];
  description = "Enables Home Assistant, with @psyclyx's config";
  extraOptions = {lib, ...}: {
    psyclyx.nixos.network.ports.home-assistant = lib.mkOption {
      type = lib.types.port;
      default = 8123;
    };
  };
  config = {config, ...}: let
    port = config.psyclyx.nixos.network.ports.home-assistant;
  in {
    networking.firewall.allowedTCPPorts = [port];
    services = {
      home-assistant = {
        enable = true;
        config = {
          default_config = {};
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
