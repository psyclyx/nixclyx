# switch-deploy — Generate and deploy switch configs from fleet data.
#
# Usage:
#   switch-deploy generate [mdf-agg01|mdf-acc01|idf-dist01|all]
#   switch-deploy deploy <mdf-agg01|mdf-acc01|idf-dist01>
#   switch-deploy diff <mdf-agg01|mdf-acc01|idf-dist01>
#
{ writeShellApplication, nix, openssh, curl, diffutils }:

writeShellApplication {
  name = "switch-deploy";
  runtimeInputs = [ nix openssh curl diffutils ];
  text = ''
    set -euo pipefail

    FLEET_DIR="''${FLEET_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
    JUMP_HOST="''${SWITCH_JUMP_HOST:-iyr}"
    ROUTEROS_USER="''${ROUTEROS_USER:-admin}"
    SWOS_USER="''${SWOS_USER:-admin}"
    SWOS_PASS="''${SWOS_PASS:-}"
    OUT_DIR="''${OUT_DIR:-./out/switch-configs}"

    # Switch name → IP address (must match fleet data).
    declare -A SWITCH_IP=(
      [mdf-agg01]="10.0.240.2"
      [mdf-acc01]="10.0.240.3"
      [idf-dist01]="10.0.240.4"
    )

    # Switch name → platform.
    declare -A SWITCH_PLATFORM=(
      [mdf-agg01]="routeros"
      [mdf-acc01]="swos"
      [idf-dist01]="routeros"
    )

    ALL_SWITCHES=(mdf-agg01 mdf-acc01 idf-dist01)

    # ── Helpers ──────────────────────────────────────────────────────

    nix_eval() {
      local expr="$1"
      nix-instantiate --eval --strict --read-write-mode \
        -E "let lib = import <nixpkgs/lib>; fleet = import $FLEET_DIR/data/fleet; gen = import $FLEET_DIR/lib/switch-config.nix lib fleet; in $expr" \
        2>/dev/null | sed 's/^"//;s/"$//' | sed 's/\\n/\n/g;s/\\"/"/g;s/\\\\/\\/g'
    }

    generate_routeros() {
      local name="$1"
      echo "Generating RouterOS config for $name..."
      mkdir -p "$OUT_DIR"
      nix_eval "gen.routeros \"$name\"" > "$OUT_DIR/$name.rsc"
      echo "  → $OUT_DIR/$name.rsc"
    }

    generate_swos() {
      local name="$1"
      echo "Generating SwOS backup for $name..."
      mkdir -p "$OUT_DIR"
      nix_eval "(gen.swos \"$name\").backup" > "$OUT_DIR/$name.swb"
      nix_eval "(gen.swos \"$name\").portMap" > "$OUT_DIR/$name-portmap.txt"
      echo "  → $OUT_DIR/$name.swb"
      echo "  → $OUT_DIR/$name-portmap.txt"
    }

    generate_one() {
      local name="$1"
      local platform="''${SWITCH_PLATFORM[$name]:-}"
      if [[ -z "$platform" ]]; then
        echo "Unknown switch: $name"; exit 1
      fi
      case "$platform" in
        routeros) generate_routeros "$name" ;;
        swos)     generate_swos "$name" ;;
        *)        echo "No generator for platform: $platform"; exit 1 ;;
      esac
    }

    # ── SSH tunnel helper for SwOS ─────────────────────────────────

    swos_tunnel_port=""
    swos_tunnel_pid=""

    open_swos_tunnel() {
      local target_ip="$1"
      swos_tunnel_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
      ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
        -L "$swos_tunnel_port:$target_ip:80" -N -f "$JUMP_HOST" \
        2>/dev/null
      swos_tunnel_pid=$!
      sleep 1
    }

    close_swos_tunnel() {
      if [[ -n "$swos_tunnel_pid" ]]; then
        kill "$swos_tunnel_pid" 2>/dev/null || true
      fi
      if [[ -n "$swos_tunnel_port" ]]; then
        lsof -ti "tcp:$swos_tunnel_port" 2>/dev/null | xargs -r kill 2>/dev/null || true
      fi
    }

    # ── Commands ─────────────────────────────────────────────────────

    cmd_generate() {
      local target="''${1:-all}"
      if [[ "$target" == "all" ]]; then
        for sw in "''${ALL_SWITCHES[@]}"; do
          generate_one "$sw"
        done
      else
        generate_one "$target"
      fi
    }

    cmd_diff() {
      local name="''${1:?Usage: switch-deploy diff <switch-name>}"
      local platform="''${SWITCH_PLATFORM[$name]:-}"
      local ip="''${SWITCH_IP[$name]:-}"
      if [[ -z "$platform" ]]; then
        echo "Unknown switch: $name"; exit 1
      fi

      case "$platform" in
        routeros)
          echo "Fetching live $name config..."
          local live
          live=$(ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$ROUTEROS_USER@$ip" '/export' 2>/dev/null)
          echo "Generating desired config..."
          local desired
          desired=$(nix_eval "gen.routeros \"$name\"")
          echo ""
          diff --color=auto -u \
            <(echo "$live") \
            <(echo "$desired") \
            --label "live ($name)" \
            --label "desired (fleet data)" || true
          ;;
        swos)
          echo "Fetching live $name backup..."
          open_swos_tunnel "$ip"
          trap close_swos_tunnel EXIT
          local live
          live=$(curl -s --max-time 10 --digest \
            -u "$SWOS_USER:$SWOS_PASS" \
            "http://localhost:$swos_tunnel_port/backup.swb")
          echo "Generating desired backup..."
          local desired
          desired=$(nix_eval "(gen.swos \"$name\").backup")
          echo ""
          diff --color=auto -u \
            <(echo "$live" | tr ',' '\n') \
            <(echo "$desired" | tr ',' '\n') \
            --label "live ($name)" \
            --label "desired (fleet data)" || true
          ;;
        *)
          echo "No diff support for platform: $platform"; exit 1 ;;
      esac
    }

    cmd_deploy() {
      local name="''${1:?Usage: switch-deploy deploy <switch-name>}"
      local platform="''${SWITCH_PLATFORM[$name]:-}"
      local ip="''${SWITCH_IP[$name]:-}"
      if [[ -z "$platform" ]]; then
        echo "Unknown switch: $name"; exit 1
      fi

      case "$platform" in
        routeros)
          generate_routeros "$name"
          echo ""
          echo "=== $name Deployment (RouterOS) ==="
          echo "This will upload and import the config to $ip via $JUMP_HOST."
          echo ""
          echo "WARNING: This will reconfigure the switch. Ensure you have"
          echo "         console/physical access in case of connectivity loss."
          echo ""
          read -rp "Continue? [y/N] " confirm
          [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

          echo "Uploading config..."
          scp -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$OUT_DIR/$name.rsc" \
            "$ROUTEROS_USER@$ip:flash/fleet-config.rsc"

          echo "Importing config..."
          ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$ROUTEROS_USER@$ip" \
            '/import file=flash/fleet-config.rsc'

          echo ""
          echo "Done. Verify connectivity, then optionally remove the uploaded file:"
          echo "  ssh -J $JUMP_HOST $ROUTEROS_USER@$ip '/file remove flash/fleet-config.rsc'"
          ;;
        swos)
          generate_swos "$name"
          echo ""
          echo "=== $name Deployment (SwOS) ==="
          echo "This will restore the SwOS backup to $ip via $JUMP_HOST."
          echo ""
          echo "WARNING: This will reconfigure the switch and reboot it."
          echo "         Ensure you have console/physical access in case of"
          echo "         connectivity loss."
          echo ""
          read -rp "Continue? [y/N] " confirm
          [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

          open_swos_tunnel "$ip"
          trap close_swos_tunnel EXIT

          echo "Uploading backup..."
          local http_code
          http_code=$(curl -s -o /dev/null -w '%{http_code}' \
            --max-time 30 --digest \
            -u "$SWOS_USER:$SWOS_PASS" \
            -X POST \
            -H "Content-Type: application/octet-stream" \
            --data-binary "@$OUT_DIR/$name.swb" \
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
          echo "No deploy support for platform: $platform"; exit 1 ;;
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
        echo "  switch-deploy generate [name|all]   Generate config files"
        echo "  switch-deploy diff <name>            Diff live vs desired"
        echo "  switch-deploy deploy <name>          Deploy to switch"
        echo ""
        echo "Switches:"
        echo "  mdf-agg01    CRS326 10G aggregation (RouterOS)"
        echo "  mdf-acc01    CSS326 1G access (SwOS)"
        echo "  idf-dist01   CRS305 distribution (RouterOS)"
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
