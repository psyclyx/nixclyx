{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.programs.zsh;
in
{
  options = {
    psyclyx.programs.zsh = {
      enable = mkEnableOption "Zsh shell with prezto";
    };
  };

  config = mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;

        defaultKeymap = "viins";

        dirHashes = {
          dl = config.xdg.userDirs.download;
          doc = config.xdg.userDirs.documents;
          proj = "${config.home.homeDirectory}/projects";
        };

        dotDir = "${config.xdg.configHome}/zsh";

        enableVteIntegration = true;

        history = {
          expireDuplicatesFirst = true;
          extended = true;
          findNoDups = true;
          ignoreAllDups = true;
          ignoreDups = true;
          save = 32000;
          saveNoDups = true;
          size = 32000;
        };

        plugins = [
          {
            name = "zsh-vi-mode";
            src = pkgs.zsh-vi-mode;
          }
          {
            name = "fzf-tab";
            src = pkgs.zsh-fzf-tab;
          }
          {
            name = "pure";
            src = inputs.zsh-pure;
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
          sudo = "sudo ";
        };

        syntaxHighlighting = {
          enable = true;
          highlighters = [ "brackets" ];
        };
      };
    };

    psyclyx.programs.shell.enable = mkDefault true;
  };
}
