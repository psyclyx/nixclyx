{ lib, pkgs, ... }:
let
  # Boot-history retention. The pre-rollback delta from each boot
  # is sent into rpool/ROOT/history as @boot-<timestamp>. Snapshots
  # older than this fall out at the next post-boot prune.
  bootHistoryRetentionDays = 14;
in
{
  # bcachefs is still enabled (kernel module + tools available) so the
  # old bcachefs pool can be mounted ad-hoc next boot for data
  # migration. Nothing about it is mounted automatically — no layout
  # declared here anymore.
  psyclyx.nixos.filesystems.bcachefs.enable = true;

  fileSystems = {
    "/" = {
      device = "rpool/ROOT/nixos";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/71AE-12DD";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    "/nix" = {
      device = "rpool/nix";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/persist" = {
      device = "rpool/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/var/log" = {
      device = "rpool/log";
      fsType = "zfs";
      neededForBoot = true;
    };

    # /home/psyc is intentionally NOT declared as a fileSystems entry.
    # pam_zfs_key.so is the sole mount path: it loads the encryption
    # key on auth and mounts the dataset on session_open. The dataset
    # keeps the default `canmount=on` (pam_zfs_key explicitly checks
    # for canmount=on and skips otherwise — `noauto` was tried and
    # is the wrong knob). `zfs mount -a` at boot tries it, sees the
    # key isn't loaded, and emits a one-line failure; that's the
    # accepted cost of the per-user-key model.

    "/root" = {
      device = "rpool/home/root";
      fsType = "zfs";
    };

    # scratchpool datasets — single-SSD scratch space, unencrypted.
    # Mount unit options pin them out of stage-1 (default) and out
    # of any per-user systemd dep chain that doesn't already
    # `RequiresMountsFor=/tmp` / `/build`.
    "/tmp" = {
      device = "scratchpool/tmp";
      fsType = "zfs";
    };

    "/build" = {
      device = "scratchpool/build";
      fsType = "zfs";
    };
  };

  # PAM unlocks rpool/home/<user> at session start using the login
  # password (`pam_zfs_key.so`). For that to be the actual unlock path
  # — not just a no-op after initrd already prompted — we override the
  # zfs module's per-pool credential request to skip /home/psyc. Only
  # /persist (which has no PAM session to hook into) prompts in
  # initrd; /home/psyc stays locked until login.
  #
  # `home-manager.startAsUserService = true` (set in default.nix)
  # makes HM activation a user systemd service with
  # `RequiresMountsFor=%h`, so it waits for /home/<user> to be
  # mounted before running. Without that, system-level HM
  # activation runs during nixos-rebuild boot — before login, before
  # PAM has mounted the dataset — and writes its symlinks into the
  # underlay (which impermanence wipes at the next boot).
  #
  # Requirement: the user's login password MUST equal the passphrase
  # set on rpool/home/psyc. If you change one, run `zfs change-key
  # rpool/home/psyc` (or `passwd` with pam_zfs_key active) to keep them
  # in sync.
  security.pam.zfs.enable = true;
  boot.zfs.requestEncryptionCredentials = lib.mkForce [ "rpool/persist" ];

  # Import bulkpool in stage-1 so the pre-rollback snapshot service
  # can send into `bulkpool/boot-history` before the rollback runs.
  # Costs ~spin-up latency on a 7.2k SAS spinner (≤ 10s in practice)
  # in exchange for the rollback being able to capture history into
  # the backup tier rather than into rpool.
  boot.zfs.extraPools = [ "bulkpool" ];

  # Impermanence: roll / back to the empty @blank snapshot on every
  # boot. Runs in stage-1 after rpool is imported and before sysroot
  # is mounted. /persist, /nix, /var/log, /home/psyc are sibling
  # datasets that survive the rollback unchanged.
  #
  # Before the rollback, we snapshot the live state and ship the
  # @blank → @boot-<ts> delta into `bulkpool/boot-history` (on the
  # 4 TB spinner). That dataset is NOT touched by the rollback, so
  # the @boot-<ts> snapshots there persist; `zfs rollback -r` then
  # wipes the @boot-<ts> on rpool/ROOT/nixos itself, and only the
  # copy on bulkpool survives.
  #
  # Recovery: `zfs clone bulkpool/boot-history@boot-<ts> bulkpool/peek/<name>`
  # then mount it, or just `zfs diff bulkpool/boot-history@blank
  # bulkpool/boot-history@boot-<ts>` to see what changed.
  boot.initrd.systemd.services.zfs-snapshot-pre-rollback = {
    description = "Snapshot / pre-rollback into bulkpool/boot-history";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-rpool.service" "zfs-import-bulkpool.service" ];
    before = [ "zfs-rollback-root.service" "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Failure tolerance is in the dep graph, not the script: the
    # rollback service uses After= (ordering only, not Requires=)
    # and wantedBy=initrd.target is a weak Wants. If this unit
    # fails, it shows as failed in the initrd journal, but the
    # rollback runs anyway and stage-2 still hands off.
    script = ''
      ts=$(date +%Y%m%d-%H%M%S)
      # First boot after this change lands: bootstrap the history
      # dataset from @blank so subsequent incrementals have a base.
      if ! zfs list -H bulkpool/boot-history >/dev/null 2>&1; then
        zfs send rpool/ROOT/nixos@blank | zfs receive bulkpool/boot-history
      fi
      zfs snapshot rpool/ROOT/nixos@boot-$ts
      # Incremental @blank → @boot-$ts; receive lands as
      # bulkpool/boot-history@boot-$ts (independent of any prior
      # @boot-* on the destination, so prune is just `zfs destroy`).
      zfs send -i @blank rpool/ROOT/nixos@boot-$ts \
        | zfs receive bulkpool/boot-history
    '';
  };

  boot.initrd.systemd.services.zfs-rollback-root = {
    description = "Rollback / to rpool/ROOT/nixos@blank";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-rpool.service" "zfs-snapshot-pre-rollback.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      zfs rollback -r rpool/ROOT/nixos@blank
    '';
  };

  # Prune boot-history snapshots older than the retention window.
  # The destination receives are independent (each boot's @boot-<ts>
  # is a standalone snapshot on history; only @blank is the shared
  # base for incremental sends), so destroying old ones never breaks
  # future send/receive lineage. Runs once per boot; the only thing
  # that adds snapshots is boots, so a timer would be overkill.
  systemd.services.zfs-prune-boot-history = {
    description = "Prune bulkpool/boot-history snapshots older than ${toString bootHistoryRetentionDays}d";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs-mount.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    path = [ pkgs.zfs pkgs.coreutils pkgs.gnugrep pkgs.findutils ];
    script = ''
      # No-op until the first boot after the history wiring lands;
      # `zfs receive` in stage-1 is what creates the dataset.
      if ! zfs list -H bulkpool/boot-history >/dev/null 2>&1; then
        exit 0
      fi
      threshold=$(date -d '${toString bootHistoryRetentionDays} days ago' +%Y%m%d-%H%M%S)
      snaps=$(zfs list -H -o name -t snapshot bulkpool/boot-history | grep '@boot-' || true)
      [ -z "$snaps" ] && exit 0
      echo "$snaps" | while read snap; do
        ts=''${snap#*@boot-}
        if [ "$ts" \< "$threshold" ]; then
          zfs destroy "$snap"
        fi
      done
    '';
  };
}
