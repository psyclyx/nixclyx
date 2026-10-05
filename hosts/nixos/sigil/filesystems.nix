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

  # 160G swap partition on the 990 PRO, beside rpool. Addressed by GPT
  # partition UUID: the two NVMe drives swap /dev/nvme{0,1} between
  # boots, and randomEncryption rewrites the partition contents every
  # boot, so a filesystem UUID/label wouldn't survive either.
  #
  # Random per-boot key: /persist and the homes are encrypted, so plain
  # swap would leak their pages to disk. Costs hibernation, which ZFS
  # doesn't support safely anyway.
  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/a90cee37-7ee5-494a-bdcd-ca3488475a79";
      randomEncryption = {
        enable = true;
        allowDiscards = true;
      };
    }
  ];

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
  # @blank → @boot-<ts> delta into rpool/ROOT/history/boot-<ts>.
  # history is outside rpool/ROOT/nixos, so `zfs rollback -r` (which
  # wipes the @boot-<ts> on nixos itself) leaves it alone. It lives on
  # rpool because rpool is the only pool imported in initrd —
  # bulkpool/scratchpool are post-boot data pools.
  #
  # rpool/ROOT/history holds a copy of @blank; each boot's delta is
  # received as its own clone of history@blank (`-o origin=`). A plain
  # incremental receive into one dataset would only work once: ZFS
  # requires the destination's newest snapshot to be the stream's base,
  # and after the first boot that's @boot-<first>, not @blank.
  #
  # Recovery: the boot datasets have mountpoint=none, so give one a
  # mountpoint first — `zfs set mountpoint=/mnt/peek
  # rpool/ROOT/history/boot-<ts>` — then browse it, or `zfs diff
  # rpool/ROOT/history@blank rpool/ROOT/history/boot-<ts>@boot-<ts>`.
  boot.initrd.systemd.services.zfs-snapshot-pre-rollback = {
    description = "Snapshot / pre-rollback into rpool/ROOT/history";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-rpool.service" ];
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
      # dataset from @blank so the incrementals have a base.
      if ! zfs list -H rpool/ROOT/history >/dev/null 2>&1; then
        zfs send rpool/ROOT/nixos@blank \
          | zfs receive -u -o canmount=off -o mountpoint=none rpool/ROOT/history
      fi
      zfs snapshot rpool/ROOT/nixos@boot-$ts
      # Incremental @blank → @boot-$ts, received as a clone of
      # history@blank. Each boot is its own dataset, independent of
      # the others, so pruning is just `zfs destroy`.
      zfs send -i @blank rpool/ROOT/nixos@boot-$ts \
        | zfs receive -u -o origin=rpool/ROOT/history@blank \
            rpool/ROOT/history/boot-$ts
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

  # Prune boot-history datasets older than the retention window.
  # Each boot-<ts> is an independent clone of history@blank (the only
  # shared base), so destroying old ones never breaks future receives.
  # Runs once per boot; the only thing that adds history is boots, so
  # a timer would be overkill.
  systemd.services.zfs-prune-boot-history = {
    description = "Prune rpool/ROOT/history boots older than ${toString bootHistoryRetentionDays}d";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs-mount.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    path = [ pkgs.zfs pkgs.coreutils pkgs.gnugrep pkgs.findutils ];
    script = ''
      # No-op until the first boot after the history wiring lands;
      # `zfs receive` in stage-1 is what creates the dataset.
      if ! zfs list -H rpool/ROOT/history >/dev/null 2>&1; then
        exit 0
      fi
      threshold=$(date -d '${toString bootHistoryRetentionDays} days ago' +%Y%m%d-%H%M%S)
      boots=$(zfs list -H -o name -t filesystem -d 1 rpool/ROOT/history | grep '/boot-' || true)
      [ -z "$boots" ] && exit 0
      echo "$boots" | while read boot; do
        ts=''${boot#*/boot-}
        if [ "$ts" \< "$threshold" ]; then
          zfs destroy -r "$boot"
        fi
      done
    '';
  };
}
