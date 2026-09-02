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
      pkgs.google-chrome
      pkgs.janet
      pkgs.psyclyx.janet-lsp
      pkgs.psyclyx.spork
      pkgs.signal-desktop

      # LLM coding agents. claude comes from programs.claude-code below.
      pkgs.llm-agents.codex
      pkgs.llm-agents.kimi-code
      pkgs.llm-agents.omp
      pkgs.llm-agents.pi
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
