# Lab-loader chain — runs in stage-2 as a normal systemd unit.
#
# Reads `pxe-host` + `pxe-spec-url` from /proc/cmdline, fetches the
# per-host spec JSON from iyr, executes its mount steps (ZFS-import,
# clevis-decrypt, ZFS-mount, NFS-mount), then kexecs into the
# target's /persist/var/nix/profiles/system.
#
# If anything fails the unit exits cleanly and the system just stays
# in stage-2 — which has sshd up via the appliance role, the operator
# key on root, networkd-managed addresses, and journal access. That's
# the "bootstrap mode" — no separate code path, no initrd-only state
# to debug.
#
# Spec shape:
#   {
#     "name": "lab-4",
#     "steps": [
#       { "op": "zfs-import", "pool": "tank" },
#       { "op": "clevis-decrypt-zfs-key",
#         "dataset": "tank/persist", "jwePath": "/jwe/tank-clevis-persist.jwe" },
#       { "op": "zfs-mount-bind",
#         "dataset": "tank/nix-shared", "to": "/mnt-nix" },
#       { "op": "zfs-mount-bind",
#         "dataset": "tank/persist/lab-4", "to": "/mnt-persist" }
#     ],
#     "kexecProfile": "/mnt-persist/var/nix/profiles/system"
#   }
{ pkgs, lib, ... }:
let
  loaderScript = pkgs.writeShellScript "lab-loader-chain" ''
    set -euo pipefail

    log() { echo "[$(date +%T)] $*"; }

    HOST=""
    SPEC_URL=""
    for kv in $(cat /proc/cmdline); do
      case "$kv" in
        pxe-host=*) HOST="''${kv#pxe-host=}";;
        pxe-spec-url=*) SPEC_URL="''${kv#pxe-spec-url=}";;
      esac
    done

    if [ -z "$HOST" ] || [ -z "$SPEC_URL" ]; then
      log "no pxe-host or pxe-spec-url on cmdline; staying in stage-2"
      exit 0
    fi

    log "host=$HOST  spec=$SPEC_URL/spec/$HOST.json"
    mkdir -p /run/lab-loader

    # Brief poll loop: even with network-online.target gating us,
    # iyr's nginx might briefly not respond on the wrong interface
    # on a fresh boot. Cheap to retry.
    fetched=
    for i in $(seq 1 15); do
      if curl -fsS --max-time 5 \
           "$SPEC_URL/spec/$HOST.json" -o /run/lab-loader/spec.json; then
        log "spec fetched on attempt $i"
        fetched=yes
        break
      fi
      log "spec fetch failed (attempt $i), retrying in 2s"
      sleep 2
    done
    if [ -z "$fetched" ]; then
      log "gave up fetching spec; staying in stage-2"
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
          log "clevis-decrypt $dataset (jwe: $SPEC_URL$jwePath)"
          curl -fsS --max-time 30 "$SPEC_URL$jwePath" \
            | clevis decrypt \
            | zfs load-key -L prompt "$dataset"
          ;;
        zfs-mount-bind)
          dataset=$(echo "$step" | jq -r .dataset)
          to=$(echo "$step" | jq -r .to)
          log "zfs mount $dataset → $to"
          mkdir -p "$to"
          # mount -t zfs works regardless of the dataset's mountpoint
          # property (legacy / none / a path) — the loader picks the
          # mountpoint, not ZFS's own metadata.
          mount -t zfs "$dataset" "$to"
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
      log "no profile at $PROFILE; staying in stage-2"
      exit 0
    fi

    TOP_STORE=$(readlink -f "$PROFILE")
    TOP_REAL="/mnt-nix''${TOP_STORE#/nix}"
    if [ ! -d "$TOP_REAL" ]; then
      log "profile resolved to $TOP_STORE; expected $TOP_REAL — missing"
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
      --append="init=$TOP_REAL/init pxe-host=$HOST $KPARAMS"

    # Best-effort teardown so the new kernel inherits a quiet system.
    umount -R /mnt-nix /mnt-persist 2>/dev/null || true
    zpool export -a 2>/dev/null || true

    log "executing kexec"
    systemctl kexec
  '';
in
{
  systemd.services.lab-loader-chain = {
    description = "lab-loader: fetch spec, mount, kexec target system";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      bash coreutils curl jq kexec-tools util-linux
      zfs nfs-utils clevis jose iproute2
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      ExecStart = "${loaderScript}";
    };
  };
}
