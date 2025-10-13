{ config, lib, ... }:
let
  direnv = {
    enable = true;
    silent = true;
    nix-direnv = {
      enable = true;
    };
  };
  fzf = {
    enable = true;
  };
  zoxide = {
    enable = true;
  };
  prezto = {
    enable = true;
    pmodules = [
      "environment"
      "terminal"
      "editor"
      "history"
      "directory"
      "spectrum"
      "utility"
      "git"
      "completion"
      "syntax-highlighting"
      "autosuggestions"
      "prompt"
    ];
    editor = {
      keymap = "vi";
      promptContext = true;
    };
    prompt = {
      theme = "pure";
      showReturnVal = true;
    };
    syntaxHighlighting = {
      highlighters = [
        "main"
        "brackets"
      ];
    };
  };
  zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableVteIntegration = true;
    shellAliases = {
      ns = "nix search nixpkgs";
      nsp = "nix-shell --run $SHELL -p";
    };
    inherit prezto;
  };
  shell = {
    enableZshIntegration = true;
  };
  cfg = config.psyclyx.programs.zsh;
in
{
  options = {
    psyclyx.programs.zsh = {
      enable = lib.mkEnableOption "Zsh shell with prezto";
    };
  };
  config = lib.mkIf cfg.enable {
    home = { inherit shell; };
    programs = {
      inherit
        direnv
        fzf
        zoxide
        zsh
        ;
    };
  };
}
