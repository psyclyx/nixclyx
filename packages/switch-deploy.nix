# switch-deploy — Generate and deploy switch configs from fleet data.
#
# Usage:
#   switch-deploy generate [mdf-agg01|mdf-acc01|idf-dist01|all]
#   switch-deploy deploy <mdf-agg01|mdf-acc01|idf-dist01>
#   switch-deploy diff <mdf-agg01|mdf-acc01|idf-dist01>
#
{ writeShellApplication, nix, openssh, curl, diffutils, xxd, python3, lsof }:

writeShellApplication {
  name = "switch-deploy";
  runtimeInputs = [ nix openssh curl diffutils xxd python3 lsof ];
  text = ''
    set -euo pipefail

    FLEET_DIR="''${FLEET_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
    JUMP_HOST="''${SWITCH_JUMP_HOST:-iyr}"
    ROUTEROS_USER="''${ROUTEROS_USER:-admin}"
    SWOS_USER="''${SWOS_USER:-admin}"
    SWOS_PASS="''${SWOS_PASS:-}"
    SODOLA_COOKIE="''${SODOLA_COOKIE:-f6fdffe48c908deb0f4c3bd36c032e72}"
    OUT_DIR="''${OUT_DIR:-./out/switch-configs}"

    # Switch name → IP address (must match fleet data).
    declare -A SWITCH_IP=(
      [mdf-agg01]="10.0.240.2"
      [mdf-acc01]="10.0.240.3"
      [mdf-brk01]="10.0.240.6"
      [idf-dist01]="10.0.240.4"
    )

    # Switch name → platform.
    declare -A SWITCH_PLATFORM=(
      [mdf-agg01]="routeros"
      [mdf-acc01]="swos"
      [mdf-brk01]="sodola"
      [idf-dist01]="routeros"
    )

    ALL_SWITCHES=(mdf-agg01 mdf-acc01 mdf-brk01 idf-dist01)

    # ── Helpers ──────────────────────────────────────────────────────

    nix_eval() {
      local expr="$1"
      nix-instantiate --eval --strict --read-write-mode \
        -E "let lib = import <nixpkgs/lib>; fleet = import $FLEET_DIR/nixclyx/data/fleet; gen = import $FLEET_DIR/nixclyx/lib/switch-config.nix lib fleet; in $expr" \
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

    generate_sodola() {
      local name="$1"
      echo "Generating Sodola binary for $name..."
      mkdir -p "$OUT_DIR"
      nix_eval "(gen.sodola \"$name\").backup" | xxd -r -p > "$OUT_DIR/$name.bin"
      nix_eval "(gen.sodola \"$name\").portMap" > "$OUT_DIR/$name-portmap.txt"
      echo "  → $OUT_DIR/$name.bin ($(wc -c < "$OUT_DIR/$name.bin") bytes)"
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
        sodola)   generate_sodola "$name" ;;
        *)        echo "No generator for platform: $platform"; exit 1 ;;
      esac
    }

    # ── SSH tunnel helper for SwOS ─────────────────────────────────

    swos_tunnel_port=""

    open_swos_tunnel() {
      local target_ip="$1"
      swos_tunnel_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
      ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
        -L "$swos_tunnel_port:$target_ip:80" -N -f "$JUMP_HOST" \
        2>/dev/null
      sleep 1
    }

    close_swos_tunnel() {
      if [[ -n "$swos_tunnel_port" ]]; then
        lsof -ti "tcp:$swos_tunnel_port" 2>/dev/null | xargs -r kill 2>/dev/null || true
      fi
    }

    # ── Sodola binary → human-readable decoder ──────────────────────

    sodola_describe() {
      python3 -c '
import struct, sys
data = open(sys.argv[1], "rb").read()

ip = ".".join(str(b) for b in data[5:9])
mask = ".".join(str(b) for b in data[9:13])
gw = ".".join(str(b) for b in data[13:17])
print(f"[system]")
print(f"ip       = {ip}")
print(f"mask     = {mask}")
print(f"gateway  = {gw}")

# Port speed capabilities
cap_names = ["auto-neg", "10M-half", "10M-full", "100M-half", "100M-full",
             "1000M-half", "1000M-full", "2500M-full", "cap8", "cap9"]
print(f"\n[port-speed]")
for p in range(9):
    caps = [cap_names[b] for b in range(10) if data[0x0138 + b*12 + p]]
    print(f"port{p+1:d}     = {",".join(caps)}")

# Mirror
m_en, m_src, m_dir = data[0x0130], data[0x0131], data[0x0132]
print(f"\n[mirror]")
if m_en:
    dirs = {1:"ingress", 2:"egress", 3:"both"}
    print(f"source   = port{m_src}")
    print(f"dest     = port{m_src+1}")
    print(f"direction= {dirs.get(m_dir, m_dir)}")
else:
    print(f"enabled  = false")

# Rate limiting
print(f"\n[rate-limit]")
for p in range(9):
    ing = struct.unpack(">I", data[0x01c8+p*4:0x01c8+p*4+4])[0]
    egr = struct.unpack(">I", data[0x01f8+p*4:0x01f8+p*4+4])[0]
    i_s = "unlimited" if ing == 0x00fffff0 else f"{ing}"
    e_s = "unlimited" if egr == 0x00fffff0 else f"{egr}"
    print(f"port{p+1:d}     = ingress:{i_s} egress:{e_s}")

# Port isolation
print(f"\n[port-isolation]")
for p in range(9):
    val = struct.unpack(">I", data[0x024e+p*4:0x024e+p*4+4])[0]
    bits = (val >> 16) & 0x1ff
    ports = ",".join(str(i+1) for i in range(9) if bits & (1<<i))
    print(f"port{p+1:d}     = {ports}")

# Native VLAN + port type
print(f"\n[port-vlan]")
for p in range(9):
    nv = struct.unpack(">H", data[0x04cc+p*2:0x04cc+p*2+2])[0]
    pt = "access" if data[0x04e4+p] == 0x02 else "trunk"
    print(f"port{p+1:d}     = type:{pt} native-vlan:{nv}")

# VLANs
vlans = []
for s in range(32):
    vid = struct.unpack(">H", data[0x0530+s*2:0x0530+s*2+2])[0]
    if vid != 0xffff:
        vlans.append((s, vid))

print(f"\n[vlans]")
seen = set()
for slot, vid in vlans:
    if vid in seen:
        continue
    seen.add(vid)
    # Name
    name = ""
    if slot >= 2:
        noff = 0x0586 + (slot-2)*26 + 10
        name = data[noff:noff+16].rstrip(b"\x00").decode("ascii", errors="replace")
    # Membership
    if slot >= 1:
        moff = 0x0586 + (slot-1)*26
        b1, b2 = data[moff+1], data[moff+2]
        members = []
        for bit in range(8):
            if b2 & (1 << bit):
                members.append(f"port{bit+1}")
        if b1 & 0x01:
            members.append("port9(tagged)")
        if b1 & 0x02:
            members.append("port9(native)")
        m_str = ",".join(members) if members else "none"
    else:
        m_str = "none"
    n_str = f" \"{name}\"" if name else ""
    print(f"vlan{vid:<5d}= members:{m_str}{n_str}")

# STP
prio = struct.unpack(">H", data[0x094b:0x094d])[0]
print(f"\n[stp]")
print(f"priority = {prio}")
print(f"max-age  = {data[0x094d]}")
print(f"hello    = {data[0x094e]}")
print(f"fwd-delay= {data[0x094f]}")
for p in range(9):
    off = 0x0950 + p*10
    cost = struct.unpack(">I", data[off:off+4])[0]
    pri = data[off+7]
    c_s = "auto" if cost == 0 else str(cost)
    print(f"port{p+1:d}     = cost:{c_s} priority:{pri}")

# Misc
print(f"\n[misc]")
print(f"igmp     = {"on" if data[0x09c9] else "off"}")
print(f"features = 0x{data[0x09cd]:02x}")
jf_en = data[0x04b5]
jf_sz = data[0x04b0]
print(f"jumbo    = {"on" if jf_en else "off"} size:{jf_sz * 1000 if jf_sz else 0}")

# QoS
queues = [data[0x09cf+p] for p in range(9)]
print(f"qos-queue= {",".join(str(q) for q in queues)}")
' "$1"
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
        sodola)
          echo "Fetching live $name backup..."
          open_swos_tunnel "$ip"
          trap close_swos_tunnel EXIT
          local live_file
          live_file=$(mktemp)
          curl -s --max-time 10 \
            -b "admin=$SODOLA_COOKIE" \
            -H "Referer: http://localhost:$swos_tunnel_port/" \
            "http://localhost:$swos_tunnel_port/config_back.cgi?cmd=conf_backup" \
            -o "$live_file"
          echo "Generating desired config..."
          local desired_file
          desired_file=$(mktemp)
          nix_eval "(gen.sodola \"$name\").backup" | xxd -r -p > "$desired_file"
          echo ""
          diff --color=auto -u \
            <(sodola_describe "$live_file") \
            <(sodola_describe "$desired_file") \
            --label "live ($name)" \
            --label "desired (fleet data)" || true
          rm -f "$live_file" "$desired_file"
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
          echo "This will reset-configuration with no-defaults and apply the"
          echo "generated config to $ip via $JUMP_HOST. The switch will REBOOT."
          echo ""
          echo "WARNING: All existing config will be wiped. Ensure you have"
          echo "         console/physical access in case of connectivity loss."
          echo ""
          read -rp "Continue? [y/N] " confirm
          [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

          echo "Uploading config..."
          scp -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$OUT_DIR/$name.rsc" \
            "$ROUTEROS_USER@$ip:flash/fleet-config.rsc"

          echo "Resetting configuration and applying..."
          ssh -o ConnectTimeout=10 -J "$JUMP_HOST" \
            "$ROUTEROS_USER@$ip" \
            '/system reset-configuration no-defaults=yes run-after-reset=flash/fleet-config.rsc'

          echo ""
          echo "Switch is rebooting. Wait ~60 seconds, then verify connectivity:"
          echo "  ssh -J $JUMP_HOST $ROUTEROS_USER@$ip '/system identity print'"
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
        sodola)
          generate_sodola "$name"
          echo ""
          echo "=== $name Deployment (Sodola) ==="
          echo "This will restore the binary backup to $ip via $JUMP_HOST."
          echo ""
          echo "WARNING: This will reconfigure the switch and REBOOT it."
          echo "         iyr WAN will be down for ~30 seconds during reboot."
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
            --max-time 30 \
            -b "admin=$SODOLA_COOKIE" \
            -H "Referer: http://localhost:$swos_tunnel_port/" \
            -F "submitFile=@$OUT_DIR/$name.bin" \
            "http://localhost:$swos_tunnel_port/config_back.cgi?cmd=conf_restore")

          if [[ "$http_code" == "200" ]]; then
            echo "Backup uploaded. Rebooting switch..."
            curl -s -o /dev/null --max-time 5 \
              -b "admin=$SODOLA_COOKIE" \
              -H "Referer: http://localhost:$swos_tunnel_port/" \
              -d "cmd=reboot" \
              "http://localhost:$swos_tunnel_port/reboot.cgi" || true
            echo "Reboot initiated. Wait ~30 seconds, then verify connectivity."
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
        echo "  mdf-brk01    SL902 2.5G iyr breakout (Sodola)"
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
