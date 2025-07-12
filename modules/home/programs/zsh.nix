{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
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
    dotDir = ".config/zsh";
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
in
{
  home = { inherit shell; };
  programs = { inherit direnv fzf zoxide zsh; };
}
