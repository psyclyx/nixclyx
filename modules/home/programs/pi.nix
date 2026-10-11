{
  path = ["psyclyx" "home" "programs" "pi"];
  description = "Pi coding agent CLI configuration";
  options = {lib, ...}: {
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        defaultProvider = "xiaomi-token-plan-sgp";
        defaultModel = "mimo-v2.6-pro";
        defaultThinkingLevel = "high";
        theme = "dark";
        autocompleteMaxVisible = 20;
        terminal = {
          clearOnShrink = true;
          showTerminalProgress = true;
        };
        showCacheMissNotices = true;
        collapseChangelog = true;
        quietStartup = true;
        enableInstallTelemetry = false;
        defaultProjectTrust = "always";
        doubleEscapeAction = "tree";
        tuiMode = "fullscreen";
        fullscreenScrollbar = "auto";
        fullscreenExitOutput = "transcript";
        hideThinkingBlock = false;
        steeringMode = "all";
        followUpMode = "all";
      };
      description = ''
        Bootstrap contents for ~/.pi/agent/settings.json. Written only when
        the file does not exist: pi mutates settings.json at runtime
        (lastChangelogVersion, /theme, model picks, …), so activation never
        re-asserts these values over an existing file.
      '';
    };
  };
  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    piPackage = pkgs.psyclyx.pi;
  in {
    home.packages = [piPackage];

    home.file = {
      # Read-only inputs symlinked straight from the store: subagent
      # definitions (scout/planner/reviewer/worker) and prompt templates.
      # The extensions (memory, subagent) travel with the wrapped pi
      # package via --extension, not through the agent dir.
      ".pi/agent/agents".source = piPackage.passthru.agentFiles;
      ".pi/agent/prompts".source = piPackage.passthru.promptFiles;
    };

    home.activation.pi-settings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      settings_file="$HOME/.pi/agent/settings.json"
      if [ ! -e "$settings_file" ]; then
        $DRY_RUN_CMD install -Dm600 /dev/stdin "$settings_file" <<'EOF'
      ${builtins.toJSON cfg.settings}
      EOF
      fi

      # Migration: the subagent extension now ships with the wrapped pi
      # package via --extension. A leftover plain copy in the user agent
      # dir would be auto-loaded on top of it — drop it.
      if [ -d "$HOME/.pi/agent/extensions/subagent" ] && [ ! -L "$HOME/.pi/agent/extensions/subagent" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.pi/agent/extensions/subagent"
      fi
    '';
  };
}
