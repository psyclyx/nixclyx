{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "system" "stylix"];
  description = "stylix config";
  config = _: {
    psyclyx.common.system.stylix.enable = true;
  };
} args
