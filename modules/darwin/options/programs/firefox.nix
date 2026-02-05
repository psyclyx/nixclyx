{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "programs" "firefox"];
  description = "Firefox browser";
  config = _: {
    homebrew.casks = ["firefox"];
  };
} args
