{
  path = ["psyclyx" "home" "programs" "pi-coding-agent"];
  description = "Pi coding agent CLI";
  config = {config, ...}: let
    secrets = config.sops.secrets;
  in {
    programs.pi-nix = {
      enable = true;
      profiles.pi.modules = [
        ({pkgs, ...}: {
          pi = {
            enable = true;

            extraPackages = with pkgs; [
              git
              jq
              ripgrep
            ];
          };

          pi.runtime = {
            launcherName = "pi";
            auth.mode = "existing";
            projectConfig = "ask";
          };

          # Telemetry/analytics default off via pi.telemetry.enable.

          pi.settings = {
            quietStartup = true;
            enableSkillCommands = true;
            compaction.enabled = true;
          };

          # web-access provider keys. Empty/placeholder secrets are harmless —
          # web-access just has no usable provider until a real key is set in
          # secrets/home/psyc.json (web-access.brave / .exa / .openai).
          pi.webSearch.keyFiles = {
            brave = secrets."web-access/brave".path;
            exa = secrets."web-access/exa".path;
            openai = secrets."web-access/openai".path;
          };

          pi.packages.registry = {
            # superpowers telemetry is covered by pi.telemetry.enable (off) via
            # the generic CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC opt-out.
            superpowers.enable = true;
            pi-ask-user.enable = true;
            plan.enable = true;
            add-dir.enable = true;
            claude-cli.enable = true;
            raw-paste.enable = true;
            usage.enable = true;
            todos.enable = true;
            simplify.enable = true;
            btw.enable = true;
            # web-access is auto-enabled by pi.webSearch above.
            subagents.enable = true;
            interactive-shell.enable = true;
            autoresearch.enable = true;
            ralph-wiggum.enable = true;
          };
        })
      ];
    };
  };
}
