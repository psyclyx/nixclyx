{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.home.programs.zsh;
in {
  options = {
    psyclyx.home.programs.zsh = {
      enable = lib.mkEnableOption "Zsh shell with prezto";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      fzf.enable = true;
      zsh = {
        enable = true;
        defaultKeymap = "viins";
        dirHashes = {
          dl = config.xdg.userDirs.download;
          doc = config.xdg.userDirs.documents;
          proj = "${config.home.homeDirectory}/projects";
        };

        dotDir = "${config.xdg.configHome}/zsh";
        enableCompletion = true;
        enableVteIntegration = true;
        history = {
          size = 4000;
        };

        localVariables = {
          ZVM_INIT_MODE = "sourcing";
          ZVM_SYSTEM_CLIPBOARD_ENABLED = true;
        };

        plugins = [
          {
            name = "zsh-vi-mode";
            src = pkgs.zsh-vi-mode;
          }
          {
            name = "pure";
            src = config.psyclyx.home.deps.zsh-pure;
          }
        ];

        setOptions = [
          "GLOB_STAR_SHORT"
          "AUTOPUSHD"
          "PROMPT_SUBST"
          "PUSHD_SILENT"
          "NO_BEEP"
          "HIST_REDUCE_BLANKS"
          "HIST_VERIFY"
          "RC_QUOTES"
          "SHORT_LOOPS"
        ];

        shellAliases = {
          sudo = "sudo "; # continue expanding aliases
        };

        syntaxHighlighting = {
          enable = true;
          highlighters = ["brackets"];
        };

        initContent = ''
          # Allow backspace to delete anywhere in insert mode, not just where you entered it
          bindkey -v '^?' backward-delete-char
          bindkey -v '^H' backward-delete-char
        '';
      };
    };

    psyclyx.home.programs.shell.enable = lib.mkDefault true;
  };
}
