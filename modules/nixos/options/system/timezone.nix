{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "timezone"];
  description = "Timezone config";
  options = {
    default = lib.mkOption {
      type = lib.types.str;
      default = "America/Los_Angeles";
      description = "Default timezone";
    };
  };
  config = {cfg, ...}: {
    time.timeZone = cfg.default;
  };
} args
