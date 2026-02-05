{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "programs" "git"];
  description = "git version control";
  config = {config, ...}: let
    info = config.psyclyx.home.info;
  in {
    programs = {
      git = {
        enable = true;
        settings.user = lib.mapAttrs (_: lib.mkDefault) {inherit (info) name email;};
        iniContent = {
          pull.rebase = true;
          core.fsmonitor = true;
        };
      };
    };
  };
} args
