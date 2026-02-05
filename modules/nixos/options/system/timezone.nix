{
  path = ["psyclyx" "nixos" "system" "timezone"];
  description = "Timezone config";
  options = {lib, ...}: {
    default = lib.mkOption {
      type = lib.types.str;
      default = "America/Los_Angeles";
      description = "Default timezone";
    };
  };
  config = {cfg, ...}: {
    time.timeZone = cfg.default;
  };
}
