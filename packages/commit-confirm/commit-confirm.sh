#!/usr/bin/env bash
# commit-confirm — self-firing rollback around a colmena NixOS deploy.
#
# A network change on the fleet router (iyr) can strand the operator: the
# control path (harness → iyr NAT → internet) rides the very host being
# changed, and there is no out-of-band access. So silence must mean revert.
#
# The revert is IN-PLACE — a profile rollback + `switch-to-configuration
# switch`, NOT a reboot. iyr's root is FDE (bcachefs); a reboot would hang
# at the unlock prompt with nobody there and bring OpenBao back sealed.
# In-place reactivation keeps the disk unlocked and services running.
#
#   apply  <host> [--timeout MIN]
#       Snapshot the current system, arm a local self-firing revert to that
#       exact snapshot (systemd timer — needs no network), then `colmena
#       apply switch`. If the new config breaks networking the timer
#       reactivates the snapshot in place. One colmena invocation (colmena
#       re-evaluates on every command, and that eval is the slow part), so
#       the window must cover eval + push + activate + your verify — default
#       10m; bump it for slow hosts. Firing early (before activation) is a
#       harmless no-op revert to the still-current snapshot.
#   commit <host>
#       Verified good: cancel the armed revert. The new config is already
#       current + boot default.
#   revert <host>
#       Roll back now — reactivate the snapshot in place.
#
# Run from the monorepo root, inside the dev shell (needs `colmena` + the
# hive). Requires root SSH to <host>.
set -euo pipefail

unit="commit-confirm-revert"
sysprofile="/nix/var/nix/profiles/system"

usage() {
  echo "usage: commit-confirm {apply|commit|revert} <host> [--timeout MIN]" >&2
  exit 2
}

cmd="${1:-}"
host="${2:-}"
[ -n "$cmd" ] && [ -n "$host" ] || usage

mins=10
shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) mins="${2:?--timeout needs a value}"; shift 2 ;;
    *) usage ;;
  esac
done

sshhost="root@$host"

case "$cmd" in
  apply)
    echo ">> [$host] snapshotting current system…" >&2
    # Exact pre-apply system path — the revert target (deterministic even if
    # the switch below fails to create a new generation).
    prev=$(ssh "$sshhost" "readlink -f $sysprofile")

    echo ">> [$host] arming in-place revert to $prev (fires in ${mins}m)…" >&2
    revert="nix-env -p $sysprofile --set $prev && $prev/bin/switch-to-configuration switch"
    ssh "$sshhost" \
      "systemctl stop ${unit}.timer 2>/dev/null || true; \
       systemd-run --on-active=${mins}min --unit=${unit} --collect sh -c '$revert'"

    echo ">> [$host] building + switching to new config (colmena evaluates now)…" >&2
    colmena apply switch --on "$host"

    cat >&2 <<EOF

⚠  [$host] new config live — auto-reverts in place (no reboot) in ${mins}m.
   Verify connectivity/health, THEN:
     commit-confirm commit $host
   Or roll back now:
     commit-confirm revert $host
EOF
    ;;

  commit)
    echo ">> [$host] committing: cancelling armed revert…" >&2
    ssh "$sshhost" "systemctl stop ${unit}.timer 2>/dev/null || true"
    echo ">> [$host] committed (new config is current + boot default)." >&2
    ;;

  revert)
    echo ">> [$host] reverting now (in-place reactivation of snapshot)…" >&2
    # Fire the armed revert immediately, then cancel the pending timer.
    ssh "$sshhost" \
      "systemctl start ${unit}.service 2>/dev/null || true; \
       systemctl stop ${unit}.timer 2>/dev/null || true"
    echo ">> [$host] revert triggered." >&2
    ;;

  *) usage ;;
esac
