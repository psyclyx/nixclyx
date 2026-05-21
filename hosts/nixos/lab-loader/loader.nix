# Lab-loader stage-1 unit — the generic spec interpreter.
#
# Reads:
#   - pxe-host=<entityname>        from /proc/cmdline
#   - pxe-spec-url=<base>          from /proc/cmdline (no trailing /)
#
# Fetches <base>/spec/<entityname>.json. Spec shape:
#
#   {
#     "name": "lab-4",
#     "steps": [
#       { "op": "zfs-import", "pool": "tank" },
#       { "op": "clevis-decrypt-zfs-key",
#         "dataset": "tank/persist",
#         "jweUrl": "<spec-base>/jwe/tank-clevis-persist.jwe" },
#       { "op": "zfs-mount-bind",
#         "dataset": "tank/nix-shared", "to": "/mnt-nix" },
#       { "op": "zfs-mount-bind",
#         "dataset": "tank/persist/lab-4", "to": "/mnt-persist" }
#     ],
#     "kexecProfile": "/mnt-persist/var/nix/profiles/system"
#   }
#
# For lab-1..3 the steps are NFS mounts pointing at lab-4's exports.
# No host-specific logic in this script: spec describes "what to
# mount where," loader executes generically, kexec.
{ pkgs, lib, ... }:
let
  loaderScript = pkgs.writeShellScript "lab-loader-chain" ''
    set -euo pipefail

    log() { echo "lab-loader: $*"; }

    HOST=""
    SPEC_URL=""
    for kv in $(cat /proc/cmdline); do
      case "$kv" in
        pxe-host=*) HOST="''${kv#pxe-host=}";;
        pxe-spec-url=*) SPEC_URL="''${kv#pxe-spec-url=}";;
      esac
    done

    if [ -z "$HOST" ] || [ -z "$SPEC_URL" ]; then
      log "missing pxe-host/pxe-spec-url on cmdline; dropping to bootstrap"
      exit 0
    fi

    log "host=$HOST  spec=$SPEC_URL/spec/$HOST.json"
    mkdir -p /run/lab-loader
    if ! curl -fsS --max-time 30 \
         "$SPEC_URL/spec/$HOST.json" -o /run/lab-loader/spec.json; then
      log "failed to fetch spec; bootstrap mode"
      exit 0
    fi

    mkdir -p /mnt-nix /mnt-persist

    while IFS= read -r step; do
      op=$(echo "$step" | jq -r .op)
      case "$op" in
        zfs-import)
          pool=$(echo "$step" | jq -r .pool)
          log "zpool import $pool"
          zpool import -f "$pool"
          ;;
        clevis-decrypt-zfs-key)
          dataset=$(echo "$step" | jq -r .dataset)
          jwePath=$(echo "$step" | jq -r .jwePath)
          jweUrl="$SPEC_URL$jwePath"
          log "clevis-decrypt → zfs load-key $dataset (jwe: $jweUrl)"
          curl -fsS --max-time 30 "$jweUrl" \
            | clevis decrypt \
            | zfs load-key -L prompt "$dataset"
          ;;
        zfs-mount-bind)
          dataset=$(echo "$step" | jq -r .dataset)
          to=$(echo "$step" | jq -r .to)
          log "zfs mount $dataset → $to"
          zfs mount "$dataset" || true   # legacy mountpoint → idempotent
          mkdir -p "$to"
          mount --bind "/$dataset" "$to"
          ;;
        nfs-mount)
          from=$(echo "$step" | jq -r .from)
          to=$(echo "$step" | jq -r .to)
          opts=$(echo "$step" | jq -r '.options // [] | join(",")')
          log "nfs mount $from → $to ($opts)"
          mkdir -p "$to"
          mount -t nfs4 -o "$opts" "$from" "$to"
          ;;
        *)
          log "unknown op '$op' — ignoring"
          ;;
      esac
    done < <(jq -c '.steps[]' /run/lab-loader/spec.json)

    PROFILE=$(jq -r .kexecProfile /run/lab-loader/spec.json)
    if [ ! -L "$PROFILE" ] && [ ! -e "$PROFILE" ]; then
      log "no profile at $PROFILE; bootstrap mode"
      exit 0
    fi

    # The profile's symlink target is an absolute /nix/store/... path.
    # On the loader, the target's /nix lives at /mnt-nix — rewrite.
    TOP_STORE=$(readlink -f "$PROFILE")
    TOP_REAL="/mnt-nix''${TOP_STORE#/nix}"

    if [ ! -d "$TOP_REAL" ]; then
      log "profile resolved to $TOP_STORE; expected at $TOP_REAL — not there"
      exit 0
    fi

    KPARAMS=""
    if [ -r "$TOP_REAL/kernel-params" ]; then
      KPARAMS=$(cat "$TOP_REAL/kernel-params")
    fi

    log "kexec → $TOP_REAL"
    kexec --load \
      "$TOP_REAL/kernel" \
      --initrd="$TOP_REAL/initrd" \
      --append="init=$TOP_REAL/init pxe-host=$HOST ip=dhcp $KPARAMS"

    # Best-effort teardown so the new kernel inherits a quiet system.
    umount -R /mnt-nix /mnt-persist 2>/dev/null || true
    zpool export -a 2>/dev/null || true

    log "executing kexec"
    systemctl kexec
  '';
in
{
  boot.initrd.systemd.services.lab-loader-chain = {
    description = "lab-loader: fetch spec, mount, kexec target system";
    wantedBy = [ "initrd.target" ];
    after = [
      "systemd-networkd-wait-online.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    # Block stage-2 switch-root until chain finishes (otherwise systemd
    # transitions to the netboot squashfs system before we kexec away).
    before = [
      "initrd-switch-root.target"
      "initrd-switch-root.service"
      "lab-loader-bootstrap-mode.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${loaderScript}";
    };
    unitConfig.DefaultDependencies = false;
  };
}
