# egregore — CLI for the egregore entity registry.
#
# Usage:
#   egregore list [--type=X] [--tag=X]
#   egregore show <entity>
#   egregore attrs <entity> [attr]
#   egregore verb <entity> <verb>
#   egregore verbs <entity>
#   egregore graph
#
{ writeShellApplication, nix, jq, coreutils, redfishtool }:

writeShellApplication {
  name = "egregore";
  runtimeInputs = [ nix jq coreutils redfishtool ];
  text = ''
    set -euo pipefail

    EGREGORE_DIR="''${EGREGORE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"

    # ── Nix evaluation ─────────────────────────────────────────────
    #
    # Reads egregore.nix from the repo root (or EGREGORE_FILE).
    # That file declares { lib = ./path/to/egregore; modules = [ ... ]; }.

    EGREGORE_FILE="''${EGREGORE_FILE:-$EGREGORE_DIR/egregore.nix}"

    if [[ ! -f "$EGREGORE_FILE" ]]; then
      # Fall back to nixclyx submodule layout
      if [[ -f "$EGREGORE_DIR/nixclyx/egregore.nix" ]]; then
        EGREGORE_FILE="$EGREGORE_DIR/nixclyx/egregore.nix"
      else
        echo "error: no egregore.nix found at $EGREGORE_FILE" >&2
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

    # ── Commands ───────────────────────────────────────────────────

    cmd_list() {
      local type_filter="" tag_filter=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --type=*) type_filter="''${1#--type=}"; shift ;;
          --tag=*)  tag_filter="''${1#--tag=}"; shift ;;
          *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
      done

      local json
      json=$(nix_eval_json "lib.mapAttrs (_: e: { inherit (e) type tags; }) fleet.entities")

      local jq_filter=".[]"
      if [[ -n "$type_filter" ]]; then
        jq_filter="$jq_filter | select(.value.type == \"$type_filter\")"
      fi
      if [[ -n "$tag_filter" ]]; then
        jq_filter="$jq_filter | select(.value.tags | index(\"$tag_filter\"))"
      fi

      echo "$json" | jq -r "to_entries[] | select(true) $(
        [[ -n "$type_filter" ]] && echo "| select(.value.type == \"$type_filter\")" || true
        [[ -n "$tag_filter" ]] && echo "| select(.value.tags | index(\"$tag_filter\"))" || true
      ) | \"\(.key)\t\(.value.type)\t\(.value.tags | join(\",\"))\"" | column -t -s $'\t'
    }

    cmd_show() {
      local name="''${1:?Usage: egregore show <entity>}"
      local json
      json=$(nix_eval_json "let e = fleet.entities.\"$name\"; in { inherit (e) type tags refs; attrs = lib.mapAttrs (_: v: if builtins.isList v then v else if builtins.isAttrs v then v else builtins.toString v) e.attrs; verbs = lib.mapAttrs (_: v: v.description) e.verbs; }")

      echo "$json" | jq -r '
        "type:  \(.type)",
        "tags:  \(.tags | join(", "))",
        (if (.refs | length) > 0 then "refs:" else empty end),
        (.refs | to_entries[] | "  \(.key) → \(.value)"),
        "attrs:",
        (.attrs | to_entries[] | "  \(.key) = \(.value)"),
        (if (.verbs | length) > 0 then "verbs:" else empty end),
        (.verbs | to_entries[] | "  \(.key) — \(.value)")
      '
    }

    cmd_attrs() {
      local name="''${1:?Usage: egregore attrs <entity> [attr]}"
      local attr="''${2:-}"

      if [[ -n "$attr" ]]; then
        nix_eval_json "fleet.entities.\"$name\".attrs.\"$attr\"" | jq .
      else
        nix_eval_json "fleet.entities.\"$name\".attrs" | jq .
      fi
    }

    cmd_verbs() {
      local name="''${1:?Usage: egregore verbs <entity>}"
      local json
      json=$(nix_eval_json "lib.mapAttrs (_: v: { inherit (v) pure description; }) fleet.entities.\"$name\".verbs")
      echo "$json" | jq -r 'to_entries[] | "\(.key)\t\(if .value.pure then "pure" else "impure" end)\t\(.value.description)"' | column -t -s $'\t'
    }

    cmd_verb() {
      local name="''${1:?Usage: egregore verb <entity> <verb> [args...]}"
      local verb="''${2:?Usage: egregore verb <entity> <verb> [args...]}"
      shift 2

      local meta
      meta=$(nix_eval_json "let v = fleet.entities.\"$name\".verbs.\"$verb\"; in { inherit (v) pure impl; }")

      local is_pure impl
      is_pure=$(echo "$meta" | jq -r '.pure')
      impl=$(echo "$meta" | jq -r '.impl')

      if [[ "$is_pure" == "true" ]]; then
        echo "$impl"
      else
        echo "=== Running $verb on $name ===" >&2
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

    # ── Main ───────────────────────────────────────────────────────

    cmd="''${1:-}"
    shift || true

    case "$cmd" in
      list|ls)  cmd_list "$@" ;;
      show)     cmd_show "$@" ;;
      attrs)    cmd_attrs "$@" ;;
      verbs)    cmd_verbs "$@" ;;
      verb|run) cmd_verb "$@" ;;
      graph)    cmd_graph "$@" ;;
      *)
        cat <<EOF
    egregore — entity registry CLI

    Usage:
      egregore list [--type=X] [--tag=X]   List entities (filterable)
      egregore show <entity>                Show entity details
      egregore attrs <entity> [attr]        Query entity attributes
      egregore verbs <entity>               List available verbs
      egregore verb <entity> <verb> [args]   Execute a verb
      egregore graph                        Output Graphviz DOT

    Environment:
      EGREGORE_DIR   Path to repo root (default: git root)
    EOF
        [[ -z "$cmd" ]] && exit 0 || exit 1
        ;;
    esac
  '';
}
