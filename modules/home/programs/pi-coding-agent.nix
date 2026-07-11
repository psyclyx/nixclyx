{
  path = ["psyclyx" "home" "programs" "pi-coding-agent"];
  description = "Pi coding agent CLI";
  config = {
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
          };
        })
      ];
    };
  };
}
