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
    home.activation.claude-code-settings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD install -Dm644 /dev/stdin "$HOME/.claude/settings.json" <<'EOF'
      ${builtins.toJSON settings}
      EOF
    '';

    home.packages = [pkgs.llm-agents.claude-code];

    home.shellAliases = {
      clauded = "claude --dangerously-skip-permissions";
      pclaude = "claude --print";
      pclauded = "claude --dangerously-skip-permissions --print";
      clauder = "cat \${PROMPT_MD:-\${1:-prompt.md}} | pclauded";
    };
  };
}
