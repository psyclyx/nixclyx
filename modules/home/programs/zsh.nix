{
  path = ["psyclyx" "home" "programs" "zsh"];
  description = "Zsh shell";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    c = config.lib.stylix.colors;
  in {
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
        ];

        setOptions = [
          "GLOB_STAR_SHORT"
          "AUTOPUSHD"
          "PROMPT_SUBST"
          "PUSHD_SILENT"
          "NO_BEEP"
          "HIST_VERIFY"
          "RC_QUOTES"
          "SHORT_LOOPS"
          "COMPLETE_IN_WORD"
          "ALWAYS_TO_END"
        ];

        shellAliases = {
          sudo = "sudo "; # continue expanding aliases
        };

        syntaxHighlighting = {
          enable = true;
          highlighters = ["brackets"];
        };

        initContent = ''
          zmodload zsh/datetime
          autoload -Uz add-zsh-hook vcs_info

          # ── smart path ─────────────────────────────────────────────
          # Hashdir-aware (%~ handles that), then shorten intermediate
          # components to the shortest unique prefix among siblings.
          _short_path() {
            local raw=''${(%):-%~}
            local -a parts=("''${(@s:/:)raw}")
            local n=''${#parts}
            (( n <= 2 )) && { print -n "$raw"; return }

            local result="''${parts[1]}"
            local i
            for (( i = 2; i < n; i++ )); do
              local expanded="''${~result}"
              local component="''${parts[$i]}"
              local abbrev="" len
              for (( len = 1; len <= ''${#component}; len++ )); do
                abbrev="''${component:0:$len}"
                local -a siblings=( "''${expanded}"/''${abbrev}*(N/) )
                (( ''${#siblings} <= 1 )) && break
              done
              result+="/''${abbrev}"
            done
            result+="/''${parts[$n]}"
            print -n "$result"
          }

          # ── vcs_info ───────────────────────────────────────────────
          zstyle ':vcs_info:*' enable git
          zstyle ':vcs_info:*' check-for-changes true
          zstyle ':vcs_info:*' stagedstr    "%F{#${c.base0B}}+%f"
          zstyle ':vcs_info:*' unstagedstr  "%F{#${c.base08}}*%f"
          zstyle ':vcs_info:git:*' formats       " %F{#${c.base0D}}%b%f%c%u"
          zstyle ':vcs_info:git:*' actionformats " %F{#${c.base0D}}%b%f|%F{#${c.base09}}%a%f%c%u"

          # ── hooks ──────────────────────────────────────────────────
          # psvar: [1]=path [2]=exit code [3]=elapsed [4]=direnv [5]=vi mode
          _prompt_precmd() {
            local ec=$?
            vcs_info
            psvar[1]="$(_short_path)"
            psvar[2]=""
            (( ec != 0 )) && psvar[2]="$ec"
            psvar[3]=""
            if [[ -n $_prompt_timer ]]; then
              local -F2 elapsed=$(( EPOCHREALTIME - _prompt_timer ))
              if (( elapsed >= 1.0 )); then
                if (( elapsed >= 3600 )); then
                  psvar[3]="$(( ''${elapsed%.*} / 3600 ))h$(( ''${elapsed%.*} % 3600 / 60 ))m"
                elif (( elapsed >= 60 )); then
                  psvar[3]="$(( ''${elapsed%.*} / 60 ))m$(( ''${elapsed%.*} % 60 ))s"
                else
                  psvar[3]="''${elapsed}s"
                fi
              fi
              unset _prompt_timer
            fi
            psvar[4]=""
            [[ -n $DIRENV_DIR ]] && psvar[4]="env"
            psvar[5]=""
          }
          _prompt_preexec() { _prompt_timer=$EPOCHREALTIME; }
          add-zsh-hook precmd  _prompt_precmd
          add-zsh-hook preexec _prompt_preexec

          # ── vi mode indicator ──────────────────────────────────────
          function zle-keymap-select {
            case $KEYMAP in
              vicmd) psvar[5]="N" ;;
              *)     psvar[5]="" ;;
            esac
            zle -R
          }
          zle -N zle-keymap-select

          # ── prompt ─────────────────────────────────────────────────
          PROMPT='%F{#${c.base0C}}%1v%f''${vcs_info_msg_0_}%(4V. %F{#${c.base03}}%4v%f.) %F{#${c.base04}}>%f '
          RPROMPT='%(5V.%F{#${c.base0E}}%5v%f .)%(3V.%F{#${c.base03}}%3v%f .)%(2V.%F{#${c.base08}}✗%2v%f.)'

          # ── keybindings ────────────────────────────────────────────
          stty -ixon
          bindkey -v '^?' backward-delete-char
          bindkey -v '^H' backward-delete-char
          bindkey -v '^Q' push-line-or-edit

          # edit-command-line: open buffer in $EDITOR
          function _edit_command_line {
            emulate -L zsh
            local tmpf="''${TMPPREFIX:-/tmp/zsh}ecl$$.zsh"
            print -r - "$BUFFER" >| "$tmpf"
            exec </dev/tty
            ''${=''${VISUAL:-''${EDITOR:-vi}}} "$tmpf"
            BUFFER="$(<$tmpf)"
            command rm -f "$tmpf"
            CURSOR=$#BUFFER
            zle reset-prompt
            zle -R
          }
          zle -N _edit_command_line
          bindkey -v '^X^E' _edit_command_line

          # ── completion styles ──────────────────────────────────────
          zstyle ':completion:*' completer _extensions _complete _approximate _files
          zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
          zstyle ':completion:*' group-name '''
          zstyle ':completion:*:descriptions' format '%F{#${c.base0B}}-- %d --%f'
          zstyle ':completion:*' menu select
        '';
      };
    };

    psyclyx.home.programs.shell.enable = lib.mkDefault true;
  };
}
