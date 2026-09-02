{ pkgs, ... }:
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

  # Every ZFS mount here is derived from the zfs-dataset entities in
  # configs/egregore/storage/sigil.nix. /home/psyc is deliberately absent
  # from the derived set: its entity declares mountedBy = "pam", so
  # pam_zfs_key.so mounts it at login and it never enters fileSystems —
  # systemd would otherwise try to mount it at boot, before any key is
  # loaded.
  #
  # /boot stays hand-declared: it is a vfat EFI partition, not a ZFS
  # dataset, so no entity describes it.
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/71AE-12DD";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # PAM unlocks rpool/home/<user> at session start using the login
  # password (`pam_zfs_key.so`). Both halves of that are now derived from
  # the dataset's `mountedBy = "pam"`: it turns on security.pam.zfs, and it
  # keeps the dataset out of the initrd encryption roots so /persist (which
  # has no PAM session to hook into) is the only thing that prompts at boot.
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
  # Storage is projected from the zfs-pool / zfs-dataset entities in
  # configs/egregore/storage/sigil.nix: fileSystems, the root/data pool
  # split (rpool imported in initrd; scratchpool + bulkpool imported after
  # boot, with their zfs-import units pinned to boot-time only — see
  # `dataPools` in filesystems/zfs.nix), boot.zfs.extraPools, the initrd
  # encryption roots, and security.pam.zfs.
  #
  # disko stays off. sigil's pools were created by hand on an EFI + swap +
  # zfs layout, and the projection's translation assumes whole-disk GPT
  # pools; since disko.enableConfig is on, emitting that wrong layout would
  # also emit wrong fileSystems. The topology blocks in the egregore data
  # are documentation of what exists, not a provisioning plan.
  psyclyx.nixos.derived.storage = {
    enable = true;
    disko.enable = false;
  };

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
