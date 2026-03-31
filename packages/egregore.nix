# egregore — CLI for the egregore entity registry.
#
# Usage:
#   egregore list [--type=X] [--tag=X]
#   egregore show <entity>
#   egregore inspect
#   egregore attrs <entity> [attr]
#   egregore verbs <entity>
#   egregore verb <verb> <entity> [args]
#   egregore graph
#
{ writeShellApplication, symlinkJoin, installShellFiles, runCommand,
  nix, jq, coreutils, curl, redfishtool,
  sodola-config, swos-config, routeros-config }:

let
  cli = writeShellApplication {
    name = "egregore";
    runtimeInputs = [ nix jq coreutils curl redfishtool sodola-config swos-config routeros-config ];
    text = ''
      set -euo pipefail

      # ── Color ──────────────────────────────────────────────────────

      USE_COLOR=""
      if [[ -t 1 ]]; then USE_COLOR=1; fi

      for arg in "$@"; do
        case "$arg" in
          --color)    USE_COLOR=1 ;;
          --no-color) USE_COLOR="" ;;
        esac
      done
      filtered_args=()
      for arg in "$@"; do
        case "$arg" in
          --color|--no-color) ;;
          *) filtered_args+=("$arg") ;;
        esac
      done
      set -- "''${filtered_args[@]+"''${filtered_args[@]}"}"

      if [[ -n "$USE_COLOR" ]]; then
        DIM=$'\e[2m'
        BOLD=$'\e[1m'
        CYAN=$'\e[36m'
        GREEN=$'\e[32m'
        YELLOW=$'\e[33m'
        MAGENTA=$'\e[35m'
        BLUE=$'\e[34m'
        RED=$'\e[31m'
        RESET=$'\e[0m'
      else
        DIM="" BOLD="" CYAN="" GREEN="" YELLOW="" MAGENTA="" BLUE="" RED="" RESET=""
      fi

      EGREGORE_DIR="''${EGREGORE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"

      # ── Nix evaluation ─────────────────────────────────────────────

      EGREGORE_FILE="''${EGREGORE_FILE:-$EGREGORE_DIR/egregore.nix}"

      if [[ ! -f "$EGREGORE_FILE" ]]; then
        if [[ -f "$EGREGORE_DIR/nixclyx/egregore.nix" ]]; then
          EGREGORE_FILE="$EGREGORE_DIR/nixclyx/egregore.nix"
        else
          echo "''${BOLD}error:''${RESET} no egregore.nix found at $EGREGORE_FILE" >&2
          echo "Set EGREGORE_FILE or create egregore.nix at your repo root." >&2
          exit 1
        fi
      fi

      PREAMBLE="let lib = import <nixpkgs/lib>; spec = import $EGREGORE_FILE; egregore = import spec.lib { inherit lib; }; fleet = egregore.eval { inherit (spec) modules; }; in"

      nix_eval_json() {
        local expr="$1"
        nix-instantiate --eval --strict --read-write-mode \
          -E "$PREAMBLE builtins.toJSON ($expr)" \
          2>/dev/null | sed 's/^"//;s/"$//' | sed 's/\\"/"/g;s/\\\\/\\/g'
      }

      nix_eval_raw() {
        local expr="$1"
        nix-instantiate --eval --strict --read-write-mode \
          -E "$PREAMBLE $expr" \
          2>/dev/null | sed 's/^"//;s/"$//' | sed 's/\\n/\n/g;s/\\"/"/g;s/\\\\/\\/g'
      }

      die() {
        echo "''${RED}error:''${RESET} $1" >&2
        shift
        for line in "$@"; do
          echo "$line" >&2
        done
        exit 1
      }

      # ── Commands ───────────────────────────────────────────────────

      cmd_list() {
        local type_filter="" tag_filter="" flat=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --type=*) type_filter="''${1#--type=}"; shift ;;
            --tag=*)  tag_filter="''${1#--tag=}"; shift ;;
            --flat)   flat=1; shift ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
          esac
        done

        local json
        json=$(nix_eval_json "lib.mapAttrs (_: e: { inherit (e) type tags; label = e.attrs.label or \"\"; }) fleet.entities")

        local filters=""
        [[ -n "$type_filter" ]] && filters+="| select(.value.type == \"$type_filter\")"
        [[ -n "$tag_filter" ]] && filters+="| select(.value.tags | index(\"$tag_filter\"))"

        # Group by type, sorted
        local grouped
        # shellcheck disable=SC2016
        local jq_group='[to_entries[] '"$filters"'] | group_by(.value.type) | .[] | .[0].value.type as $t | "\($t)" , (.[] | "\(.key)\t\(.value.tags | join(","))\t\(.value.label)"), ""'
        grouped=$(echo "$json" | jq -r "$jq_group")

        local current_type=""
        local first_group=1
        while IFS=$'\t' read -r line rest_tags rest_label; do
          # Lines without tabs are type headers (or blank separators)
          if [[ -z "$rest_tags" && -z "$rest_label" ]]; then
            if [[ -z "$line" ]]; then
              continue  # blank separator
            fi
            # Type header
            if [[ -z "$flat" ]]; then
              [[ "$first_group" == "1" ]] || echo ""
              first_group=0
              printf "''${CYAN}%s''${RESET}\n" "$line"
            fi
            current_type="$line"
          else
            local name="$line"
            local tags="$rest_tags"
            local label="$rest_label"
            local tag_str=""
            if [[ -n "$tags" ]]; then
              tag_str="''${YELLOW}[''${tags}]''${RESET}"
            fi
            if [[ -n "$flat" ]]; then
              printf "  ''${BOLD}%-16s''${RESET} ''${CYAN}%-12s''${RESET} %-24s %s\n" "$name" "$current_type" "$tag_str" "$label"
            else
              if [[ -n "$tags" && -n "$label" ]]; then
                printf "  ''${BOLD}%-16s''${RESET} %s  ''${DIM}%s''${RESET}\n" "$name" "$label" "$tag_str"
              elif [[ -n "$label" ]]; then
                printf "  ''${BOLD}%-16s''${RESET} %s\n" "$name" "$label"
              elif [[ -n "$tags" ]]; then
                printf "  ''${BOLD}%-16s''${RESET} %s\n" "$name" "$tag_str"
              else
                printf "  ''${BOLD}%s''${RESET}\n" "$name"
              fi
            fi
          fi
        done <<< "$grouped"
      }

      cmd_show() {
        [[ $# -ge 1 ]] || die "missing entity name" \
          "usage: egregore show ''${CYAN}<entity>''${RESET}" \
          "run ''${DIM}egregore list''${RESET} to see available entities."
        local name="$1"
        local json
        json=$(nix_eval_json "let e = fleet.entities.\"$name\"; in { inherit (e) type tags refs; attrs = lib.mapAttrs (_: v: if builtins.isList v then v else if builtins.isAttrs v then v else builtins.toString v) e.attrs; verbs = lib.mapAttrs (_: v: { inherit (v) pure description; }) e.verbs; }")

        [[ -n "$json" ]] || die "entity ''${BOLD}$name''${RESET} not found" \
          "run ''${DIM}egregore list''${RESET} to see available entities."

        echo "$json" | jq -r --arg B "$BOLD" --arg R "$RESET" --arg C "$CYAN" --arg G "$GREEN" --arg Y "$YELLOW" --arg M "$MAGENTA" --arg BL "$BLUE" --arg D "$DIM" '
          .type as $type | .tags as $tags | .refs as $refs | .attrs as $attrs | .verbs as $verbs |

          "\($B)'"$name"'\($R)  \($C)\($type)\($R)\(if ($tags | length) > 0 then "  \($Y)\($tags | join(", "))\($R)" else "" end)",
          "",
          (if ($refs | length) > 0 then
            "\($BL)refs\($R)",
            ($refs | to_entries[] | "  \($BL)\(.key)\($R) \($D)→\($R) \($B)\(.value)\($R)"),
            ""
          else empty end),
          "\($G)attrs\($R)",
          ($attrs | to_entries | sort_by(.key)[] | "  \($G)\(.key)\($R) = \(.value)"),
          (if ($verbs | length) > 0 then
            "",
            "\($M)verbs\($R)",
            ($verbs | to_entries | sort_by(.key)[] |
              "  \($M)\(.key)\($R) \($D)\(if .value.pure then "(pure)" else "" end) \(.value.description)\($R)")
          else empty end)
        '
      }

      cmd_attrs() {
        [[ $# -ge 1 ]] || die "missing entity name" \
          "usage: egregore attrs ''${CYAN}<entity>''${RESET} [attr]" \
          "run ''${DIM}egregore list''${RESET} to see available entities."
        local name="$1"
        local attr="''${2:-}"

        if [[ -n "$attr" ]]; then
          nix_eval_json "fleet.entities.\"$name\".attrs.\"$attr\"" | jq -C .
        else
          nix_eval_json "fleet.entities.\"$name\".attrs" | jq -C .
        fi
      }

      # Show all verbs across all entities, grouped by verb then by type.
      show_all_verbs() {
        local json
        json=$(nix_eval_json "lib.mapAttrs (name: e: { inherit (e) type; verbs = lib.mapAttrs (_: v: { inherit (v) description; }) e.verbs; }) fleet.entities")

        [[ -n "$json" ]] || return

        echo "$json" | jq -r '
          [ to_entries[] | .key as $ent | .value.type as $type |
            .value.verbs | to_entries[] |
            {verb: .key, desc: .value.description, entity: $ent, type: $type} ]
          | group_by(.verb) | sort_by(.[0].verb)[]
          | .[0].verb as $v | .[0].desc as $d |
            group_by(.type) | sort_by(.[0].type)[] |
            .[0].type as $t | [.[].entity] | sort as $ents |
            "\($v)\t\($d)\t\($t)\t\($ents | join(", "))"
        ' | {
          local last_verb=""
          while IFS=$'\t' read -r verb desc typ ents; do
            if [[ "$verb" != "$last_verb" ]]; then
              [[ -n "$last_verb" ]] && echo ""
              printf "  ''${MAGENTA}%s''${RESET}  ''${DIM}%s''${RESET}\n" "$verb" "$desc"
              last_verb="$verb"
            fi
            printf "    ''${CYAN}%-12s''${RESET} %s\n" "$typ" "$ents"
          done
        }
      }

      cmd_verbs() {
        if [[ $# -eq 0 ]]; then
          show_all_verbs
          return
        fi
        local name="$1"
        local json
        json=$(nix_eval_json "lib.mapAttrs (_: v: { inherit (v) pure description defaults; }) fleet.entities.\"$name\".verbs")

        [[ -n "$json" ]] || die "entity ''${BOLD}$name''${RESET} not found" \
          "run ''${DIM}egregore list''${RESET} to see available entities."

        echo "$json" | jq -r 'to_entries | sort_by(.key)[] | "\(.key)\t\(if .value.pure then "pure" else "impure" end)\t\(.value.description)\t\(.value.defaults | join(" "))"' | while IFS=$'\t' read -r verb kind desc defs; do
          local def_str=""
          if [[ -n "$defs" ]]; then
            def_str=" ''${DIM}[''${defs}]''${RESET}"
          fi
          printf "  ''${MAGENTA}%-16s''${RESET} ''${DIM}%-8s''${RESET} %s%s\n" "$verb" "$kind" "$desc" "$def_str"
        done
      }

      cmd_verb() {
        if [[ $# -eq 0 ]]; then
          echo "''${RED}error:''${RESET} missing verb name" >&2
          echo "usage: egregore verb ''${MAGENTA}<verb>''${RESET} <entity> [args...]" >&2
          echo "" >&2
          show_all_verbs >&2
          exit 1
        fi
        local verb="$1"

        [[ $# -ge 2 ]] || die "missing entity name for verb ''${MAGENTA}$verb''${RESET}" \
          "usage: egregore verb $verb ''${BOLD}<entity>''${RESET} [args...]" \
          "run ''${DIM}egregore list''${RESET} to see available entities."
        local name="$2"
        shift 2

        local meta
        meta=$(nix_eval_json "let v = fleet.entities.\"$name\".verbs.\"$verb\"; in { inherit (v) pure impl defaults; }") || true

        if [[ -z "$meta" ]]; then
          die "verb ''${MAGENTA}$verb''${RESET} not found on entity ''${BOLD}$name''${RESET}" \
            "run ''${DIM}egregore verbs $name''${RESET} to see available verbs."
        fi

        local is_pure impl
        is_pure=$(echo "$meta" | jq -r '.pure')
        impl=$(echo "$meta" | jq -r '.impl')

        # Use verb defaults when no CLI args given.
        if [[ $# -eq 0 ]]; then
          local -a defs
          readarray -t defs < <(echo "$meta" | jq -r '.defaults[]')
          if [[ ''${#defs[@]} -gt 0 ]]; then
            set -- "''${defs[@]}"
          fi
        fi

        if [[ "$is_pure" == "true" ]]; then
          echo "$impl"
        else
          echo "''${BOLD}=== $verb → $name ===''${RESET}" >&2
          eval "$impl"
        fi
      }

      cmd_graph() {
        nix_eval_raw 'let
          nodes = lib.mapAttrsToList (name: e: let
            shape = if e.type == "network" then "diamond"
              else if e.type == "host" then "box"
              else if e.type == "ha-group" then "octagon"
              else "ellipse";
            label = e.attrs.label or name;
          in "  \"" + name + "\" [label=\"" + label + "\" shape=" + shape + "];")
          fleet.entities;
          edges = lib.concatLists (lib.mapAttrsToList (name: e:
            lib.mapAttrsToList (ref: target:
              "  \"" + name + "\" -> \"" + target + "\" [label=\"" + ref + "\"];")
            e.refs) fleet.entities);
        in "digraph egregore {\n  rankdir=LR;\n" + lib.concatStringsSep "\n" (nodes ++ edges) + "\n}"'
      }

      cmd_inspect() {
        local json
        json=$(nix_eval_json "lib.mapAttrs (name: e: { inherit (e) type tags refs; config = lib.filterAttrs (_: v: ! builtins.isAttrs v && ! builtins.isList v && ! builtins.isFunction v) (builtins.getAttr e.type e); }) fleet.entities")

        [[ -n "$json" ]] || die "no entities found"

        echo "$json" | jq -r --arg B "$BOLD" --arg R "$RESET" --arg C "$CYAN" --arg Y "$YELLOW" --arg BL "$BLUE" --arg D "$DIM" '
          [to_entries[] | {name: .key} + .value]
          | group_by(.type) | sort_by(.[0].type)[]
          | .[0].type as $type
          | ([.[].name | length] | max) as $nw
          | "\($C)\($type)\($R)",
            (sort_by(.name)[] |
              "  \($B)\(.name)\($R)\(" " * ($nw - (.name | length) + 2))\(
                [.config | to_entries | sort_by(.key)[] |
                  "\($D)\(.key)\($R) \(
                    if .value | type == "array" then .value | map(tostring) | join(",")
                    elif .value | type == "object" then .value | tostring
                    elif .value == "" then "-"
                    else .value end)"
                ] | join("  "))\(
                if (.refs | length) > 0 then
                  "  \([.refs | to_entries | sort_by(.key)[] |
                    "\($BL)\(.key)\($R) \($D)→\($R) \($B)\(.value)\($R)"] | join("  "))"
                else "" end)\(
                if (.tags | length) > 0 then
                  "  \($Y)\(.tags | join(", "))\($R)"
                else "" end)"
            ),
            ""
        '
      }

      # ── Main ───────────────────────────────────────────────────────

      cmd="''${1:-}"
      shift || true

      case "$cmd" in
        list|ls)  cmd_list "$@" ;;
        show)     cmd_show "$@" ;;
        inspect)  cmd_inspect "$@" ;;
        attrs)    cmd_attrs "$@" ;;
        verbs)    cmd_verbs "$@" ;;
        verb|run) cmd_verb "$@" ;;
        graph)    cmd_graph "$@" ;;
        "")
          echo "''${BOLD}egregore''${RESET} — entity registry CLI"
          echo ""
          echo "''${BOLD}Usage:''${RESET}"
          echo "  egregore ''${CYAN}list''${RESET}    [--type=X] [--tag=X]  List entities"
          echo "  egregore ''${CYAN}show''${RESET}    <entity>              Entity overview"
          echo "  egregore ''${CYAN}inspect''${RESET}                       Full fleet overview"
          echo "  egregore ''${CYAN}attrs''${RESET}   <entity> [attr]       Query attributes"
          echo "  egregore ''${CYAN}verbs''${RESET}   [entity]              List verbs"
          echo "  egregore ''${CYAN}verb''${RESET}    <verb> <entity> [..]  Execute a verb"
          echo "  egregore ''${CYAN}graph''${RESET}                         Graphviz DOT"
          echo ""
          echo "''${BOLD}Flags:''${RESET}"
          echo "  --color / --no-color    Force color on/off (auto-detects tty)"
          echo ""
          echo "''${BOLD}Environment:''${RESET}"
          echo "  EGREGORE_DIR    Repo root ''${DIM}(default: git root)''${RESET}"
          echo "  EGREGORE_FILE   Entry point ''${DIM}(default: \$EGREGORE_DIR/egregore.nix)''${RESET}"
          ;;
        *)
          die "unknown command ''${CYAN}$cmd''${RESET}" \
            "run ''${DIM}egregore''${RESET} for usage."
          ;;
      esac
    '';
  };

  completions = runCommand "egregore-completions" {
    nativeBuildInputs = [ installShellFiles ];
  } ''
    mkdir -p $out
    installShellCompletion --bash --name egregore.bash ${./egregore-completion.bash}
    installShellCompletion --zsh --name _egregore ${./egregore-completion.zsh}
  '';
in
  symlinkJoin {
    name = "egregore";
    paths = [ cli completions ];
  }
