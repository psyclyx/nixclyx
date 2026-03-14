# switch-deploy — Generate and deploy switch configs from fleet data.
#
# Usage:
#   switch-deploy generate [crs326|css326|all]   # write configs to ./out/
#   switch-deploy deploy crs326                   # push RouterOS config
#   switch-deploy deploy css326                   # push SwOS backup
#   switch-deploy diff crs326                     # show diff against live
#   switch-deploy diff css326                     # show diff against live
#
{ writeShellApplication, nix, openssh, curl, diffutils }:

writeShellApplication {
  name = "switch-deploy";
  runtimeInputs = [ nix openssh curl diffutils ];
  text = ''
    set -euo pipefail

    FLEET_DIR="''${FLEET_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
    JUMP_HOST="''${SWITCH_JUMP_HOST:-iyr}"
    CRS326_HOST="''${CRS326_HOST:-10.0.240.2}"
    CSS326_HOST="''${CSS326_HOST:-10.0.240.3}"
    ROUTEROS_USER="''${ROUTEROS_USER:-admin}"
    SWOS_USER="''${SWOS_USER:-admin}"
    SWOS_PASS="''${SWOS_PASS:-}"
    OUT_DIR="''${OUT_DIR:-./out/switch-configs}"

    # ── Helpers ──────────────────────────────────────────────────────

    nix_eval() {
      local expr="$1"
      nix-instantiate --eval --strict --read-write-mode \
        -E "let lib = import <nixpkgs/lib>; fleet = import $FLEET_DIR/data/fleet; gen = import $FLEET_DIR/lib/switch-config.nix lib fleet; in $expr" \
        2>/dev/null | sed 's/^"//;s/"$//' | sed 's/\\n/\n/g;s/\\"/"/g;s/\\\\/\\/g'
    }

    generate_crs326() {
      echo "Generating CRS326 RouterOS config..."
      mkdir -p "$OUT_DIR"
      nix_eval 'gen.routeros "crs326"' > "$OUT_DIR/crs326.rsc"
      echo "  → $OUT_DIR/crs326.rsc"
    }

    generate_css326() {
      echo "Generating CSS326 SwOS backup..."
      mkdir -p "$OUT_DIR"
      nix_eval 'gen.swos "css326"' | grep -oP '(?<=backup = ").*(?="; portMap)' > "$OUT_DIR/css326.swb" || \
        nix_eval '(gen.swos "css326").backup' > "$OUT_DIR/css326.swb"
      nix_eval '(gen.swos "css326").portMap' > "$OUT_DIR/css326-portmap.txt"
      echo "  → $OUT_DIR/css326.swb"
      echo "  → $OUT_DIR/css326-portmap.txt"
    }

    # ── SSH tunnel helper for CSS326 ─────────────────────────────────

    swos_tunnel_port=""
    swos_tunnel_pid=""

    open_swos_tunnel() {
      swos_tunnel_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
      ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
        -L "$swos_tunnel_port:$CSS326_HOST:80" -N -f "$JUMP_HOST" \
        2>/dev/null
      swos_tunnel_pid=$!
      sleep 1
    }

    close_swos_tunnel() {
      if [[ -n "$swos_tunnel_pid" ]]; then
        kill "$swos_tunnel_pid" 2>/dev/null || true
      fi
      # Also kill any lingering tunnel
      if [[ -n "$swos_tunnel_port" ]]; then
        lsof -ti "tcp:$swos_tunnel_port" 2>/dev/null | xargs -r kill 2>/dev/null || true
      fi
    }

    # ── Commands ─────────────────────────────────────────────────────

    cmd_generate() {
      local target="''${1:-all}"
      case "$target" in
        crs326) generate_crs326 ;;
        css326) generate_css326 ;;
        all)    generate_crs326; generate_css326 ;;
        *)      echo "Unknown target: $target"; exit 1 ;;
      esac
    }

    cmd_diff() {
      local target="''${1:?Usage: switch-deploy diff <crs326|css326>}"
      case "$target" in
        crs326)
          echo "Fetching live CRS326 config..."
          local live
          live=$(ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$ROUTEROS_USER@$CRS326_HOST" '/export' 2>/dev/null)
          echo "Generating desired config..."
          local desired
          desired=$(nix_eval 'gen.routeros "crs326"')
          echo ""
          diff --color=auto -u \
            <(echo "$live") \
            <(echo "$desired") \
            --label "live (CRS326)" \
            --label "desired (fleet data)" || true
          ;;
        css326)
          echo "Fetching live CSS326 backup..."
          open_swos_tunnel
          trap close_swos_tunnel EXIT
          local live
          live=$(curl -s --max-time 10 --digest \
            -u "$SWOS_USER:$SWOS_PASS" \
            "http://localhost:$swos_tunnel_port/backup.swb")
          echo "Generating desired backup..."
          local desired
          desired=$(nix_eval '(gen.swos "css326").backup')
          echo ""
          # Pretty-print for readable diff: one section per line
          diff --color=auto -u \
            <(echo "$live" | tr ',' '\n') \
            <(echo "$desired" | tr ',' '\n') \
            --label "live (CSS326)" \
            --label "desired (fleet data)" || true
          ;;
        *)
          echo "Unknown target: $target"; exit 1 ;;
      esac
    }

    cmd_deploy() {
      local target="''${1:?Usage: switch-deploy deploy <crs326|css326>}"
      case "$target" in
        crs326)
          generate_crs326
          echo ""
          echo "=== CRS326 Deployment ==="
          echo "This will upload and import the config to $CRS326_HOST via $JUMP_HOST."
          echo ""
          echo "WARNING: This will reconfigure the switch. Ensure you have"
          echo "         console/physical access in case of connectivity loss."
          echo ""
          read -rp "Continue? [y/N] " confirm
          [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

          echo "Uploading config..."
          scp -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$OUT_DIR/crs326.rsc" \
            "$ROUTEROS_USER@$CRS326_HOST:flash/fleet-config.rsc"

          echo "Importing config..."
          ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$ROUTEROS_USER@$CRS326_HOST" \
            '/import file=flash/fleet-config.rsc'

          echo ""
          echo "Done. Verify connectivity, then optionally remove the uploaded file:"
          echo "  ssh -J $JUMP_HOST $ROUTEROS_USER@$CRS326_HOST '/file remove flash/fleet-config.rsc'"
          ;;
        css326)
          generate_css326
          echo ""
          echo "=== CSS326 Deployment ==="
          echo "This will restore the SwOS backup to $CSS326_HOST via $JUMP_HOST."
          echo ""
          echo "WARNING: This will reconfigure the switch and reboot it."
          echo "         Ensure you have console/physical access in case of"
          echo "         connectivity loss."
          echo ""
          read -rp "Continue? [y/N] " confirm
          [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

          open_swos_tunnel
          trap close_swos_tunnel EXIT

          echo "Uploading backup..."
          local http_code
          http_code=$(curl -s -o /dev/null -w '%{http_code}' \
            --max-time 30 --digest \
            -u "$SWOS_USER:$SWOS_PASS" \
            -X POST \
            -H "Content-Type: application/octet-stream" \
            --data-binary "@$OUT_DIR/css326.swb" \
            "http://localhost:$swos_tunnel_port/backup.swb")

          if [[ "$http_code" == "200" ]]; then
            echo "Backup uploaded successfully. Switch will reboot."
            echo "Wait ~30 seconds, then verify connectivity."
          else
            echo "Upload failed with HTTP $http_code"
            exit 1
          fi
          ;;
        *)
          echo "Unknown target: $target"; exit 1 ;;
      esac
    }

    # ── Main ─────────────────────────────────────────────────────────

    cmd="''${1:-}"
    shift || true

    case "$cmd" in
      generate|gen) cmd_generate "$@" ;;
      diff)         cmd_diff "$@" ;;
      deploy)       cmd_deploy "$@" ;;
      *)
        echo "switch-deploy — Generate and deploy switch configs from fleet data"
        echo ""
        echo "Usage:"
        echo "  switch-deploy generate [crs326|css326|all]  Generate config files"
        echo "  switch-deploy diff <crs326|css326>          Diff live vs desired"
        echo "  switch-deploy deploy <crs326|css326>        Deploy to switch"
        echo ""
        echo "Environment:"
        echo "  FLEET_DIR          Path to nixclyx repo (default: git root)"
        echo "  SWITCH_JUMP_HOST   SSH jump host (default: iyr)"
        echo "  ROUTEROS_USER      RouterOS SSH user (default: admin)"
        echo "  SWOS_USER          SwOS HTTP user (default: admin)"
        echo "  SWOS_PASS          SwOS HTTP password (default: empty)"
        exit 1
        ;;
    esac
  '';
}
