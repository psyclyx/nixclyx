{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "system" "security"];
  description = "security settings";
  config = _: {
    security = {
      pam.services.sudo_local.touchIdAuth = true;
    };
  };
} args
