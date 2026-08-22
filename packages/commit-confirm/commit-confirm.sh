#!/usr/bin/env bash
# commit-confirm — self-firing rollback around a colmena NixOS deploy.
#
# A network change on the fleet router (iyr) can strand the operator: the
# control path (harness → iyr NAT → internet) rides the very host being
# changed, and there is no out-of-band access. So silence must mean revert.
#
#   apply  <host> [--timeout MIN]
#       Pre-stage the closure (safe, no activation), then arm a self-firing
#       reboot on the host and activate the new config as `test` — NOT the
#       boot default. If the change breaks networking, the scheduled reboot
#       (local systemd timer, needs no network) fires and the host boots
#       back into the previous, known-good generation. Default window 3m.
#   commit <host>
#       Verified good: cancel the reboot and promote the running (tested)
#       config to the boot default. No rebuild.
#   revert <host>
#       Roll back now — reboot into the previous generation.
#
# Run from the monorepo root, inside the dev shell (needs `colmena` + the
# hive). Requires root SSH to <host>.
set -euo pipefail

unit="commit-confirm-revert"

usage() {
  echo "usage: commit-confirm {apply|commit|revert} <host> [--timeout MIN]" >&2
  exit 2
}

cmd="${1:-}"
host="${2:-}"
[ -n "$cmd" ] && [ -n "$host" ] || usage

mins=3
shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) mins="${2:?--timeout needs a value}"; shift 2 ;;
    *) usage ;;
  esac
done

sshhost="root@$host"

arm() {
  # Clear any stale timer, then schedule a one-shot reboot. Transient units
  # do not survive the reboot, so a fired revert disarms itself.
  ssh "$sshhost" \
    "systemctl stop ${unit}.timer 2>/dev/null || true; \
     systemd-run --on-active=${mins}min --unit=${unit} --collect systemctl reboot"
}

case "$cmd" in
  apply)
    echo ">> [$host] pre-staging closure (build + copy; no activation)…" >&2
    colmena apply push --on "$host"

    echo ">> [$host] arming self-firing revert (reboot in ${mins}m)…" >&2
    arm

    echo ">> [$host] activating new config as TEST (reboot discards it)…" >&2
    colmena apply test --on "$host"

    cat >&2 <<EOF

⚠  [$host] new config live on TEST — auto-reverts (reboot) in ${mins}m.
   Verify connectivity/health, THEN:
     commit-confirm commit $host
   Or roll back now:
     commit-confirm revert $host
EOF
    ;;

  commit)
    echo ">> [$host] committing: cancel revert + set tested config as boot default…" >&2
    ssh "$sshhost" \
      "systemctl stop ${unit}.timer 2>/dev/null || true; \
       /run/current-system/bin/switch-to-configuration boot"
    echo ">> [$host] committed." >&2
    ;;

  revert)
    echo ">> [$host] reverting now (reboot into previous generation)…" >&2
    ssh "$sshhost" "systemctl reboot" || true
    echo ">> [$host] revert triggered." >&2
    ;;

  *) usage ;;
esac
