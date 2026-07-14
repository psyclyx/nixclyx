{
  path = ["psyclyx" "home" "programs" "git"];
  description = "git version control";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    info = config.psyclyx.home.info;
  in {
    home.packages = [pkgs.josh];
    programs = {
      git = {
        enable = true;
        ignores = [".codex" "**/.claude/settings.local.json"];
        settings.user = lib.mapAttrs (_: lib.mkDefault) {inherit (info) name email;};
        iniContent = {
          pull.rebase = true;
          core.fsmonitor = true;
          submodule.recurse = true;
        };
      };
    };
  };
}
