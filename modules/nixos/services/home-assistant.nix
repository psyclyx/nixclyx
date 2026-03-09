{
  path = ["psyclyx" "nixos" "services" "home-assistant"];
  description = "Enables Home Assistant, with @psyclyx's config";
  config = {config, lib, ...}: {
    psyclyx.nixos.network.ports.home-assistant = lib.mkDefault 8123;

    services = {
      home-assistant = {
        enable = true;
        config = {
          default_config = {};
          http.server_port = builtins.head config.psyclyx.nixos.network.ports.home-assistant.tcp;
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
