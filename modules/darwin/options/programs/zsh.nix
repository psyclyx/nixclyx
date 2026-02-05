{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "programs" "zsh"];
  description = "zsh shell";
  config = _: {
    programs = {
      zsh = {
        enable = true;
        enableGlobalCompInit = false;
      };
    };
  };
} args
