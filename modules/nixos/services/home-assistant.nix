{ config, lib, ... }:
let
  cfg = config.psyclyx.services.home-assistant;
in
{
  options = {
    psyclyx.services.home-assistant = {
      enable = lib.mkEnableOption "Enables Home Assistant, with @psyclyx's config";
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      extraComponents = [
        "esphome"
        "met"
        "radio_browser"
        "zha"
        "ios"
      ];
      config = {
        default_config = { };
      };
    };
  };
}
