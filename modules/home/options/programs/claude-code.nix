{
  path = ["psyclyx" "home" "programs" "claude-code"];
  description = "Claude Code CLI configuration";
  options = {lib, ...}: {
    disableTelemetry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable telemetry, error reporting, and surveys";
    };
    disableAttribution = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable commit and PR attribution";
    };
  };
  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    settings = lib.filterAttrs (_: v: v != {}) {
      attribution = lib.mkIf cfg.disableAttribution {
        commit = "";
        pr = "";
      };
      env = lib.mkIf cfg.disableTelemetry {
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      };
    };
  in {
    home.packages = [pkgs.claude-code];
    home.file.".claude/settings.json".text = builtins.toJSON settings;
    home.shellAliases.clauded = "claude --dangerously-skip-permissions";
  };
}
