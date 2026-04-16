{
  path = ["psyclyx" "home" "profiles" "psyc" "desktop"];
  description = "psyc desktop home config";
  config = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = [
      pkgs.element-desktop
      pkgs.janet
      pkgs.psyclyx.janet-lsp
      pkgs.psyclyx.spork
      pkgs.signal-desktop

      # LLM coding agents
      pkgs.llm-agents.opencode
      pkgs.llm-agents.codex
      pkgs.llm-agents.gemini-cli
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = true;
        claude-code.enable = true;
        emacs.enable = true;
        firefox.enable = true;
        ghostty = {
          enable = true;
          defaultTerminal = true;
        };
        sway.enable = true;
      };
    };
  };
}
