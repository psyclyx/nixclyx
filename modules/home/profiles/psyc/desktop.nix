{
  path = ["psyclyx" "home" "profiles" "psyc" "desktop"];
  description = "psyc desktop home config";
  config = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = [
      pkgs.google-chrome
      pkgs.signal-desktop

      # LLM coding agents. claude comes from programs.claude-code below;
      # pi comes from the pi module (subagent extension + agent files).
      pkgs.llm-agents.codex
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = true;
        claude-code.enable = true;
        firefox.enable = true;
        ghostty = {
          enable = true;
          defaultTerminal = true;
        };
        pi.enable = true;
      };
    };
  };
}
