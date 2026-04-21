{
  path = ["psyclyx" "nixos" "filesystems" "impermanence"];
  description = "bcachefs root impermanence (wipe-on-boot)";
  options = {lib, ...}: let
    retentionOptions = import ../../../lib/retention.nix lib;
  in {
    device = lib.mkOption {
      type = lib.types.str;
      description = "bcachefs device path (e.g. /dev/disk/by-partlabel/nvme0-root)";
    };

    subvolume = lib.mkOption {
      type = lib.types.str;
      default = "subvolumes/root";
      description = "Path within bcachefs to the root subvolume group (containing @blank and @live)";
    };

    prune = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to prune old root snapshots according to the retention policy.";
    };

    retention = retentionOptions {monthly = 3;};
  };

  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    pruneScript = import ../../../lib/bcachefs-prune.nix;
  in {
    # preservation bind-mounts /etc/machine-id from /persist, making it a
    # mount point. This triggers systemd-machine-id-commit which then fails
    # because the mount isn't tmpfs. The machine-id is already persistent.
    systemd.services.systemd-machine-id-commit.enable = false;

    boot.initrd.systemd.services.impermanence-root-rollback = {
      description = "Roll back root to blank bcachefs snapshot";
      wantedBy = ["initrd.target"];
      after = ["initrd-root-device.target"];
      before = ["sysroot.mount"];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        KeyringMode = "inherit";
      };
      script = ''
        set -euo pipefail
        mnt=/run/impermanence-mnt
        mkdir -p "$mnt"
        mount -t bcachefs ${lib.escapeShellArg cfg.device} "$mnt"

        root="$mnt/${lib.escapeShellArg cfg.subvolume}"
        timestamp=$(date +%Y-%m-%dT%H:%M:%S)

        if [ -d "$root/@live" ]; then
          mv "$root/@live" "$root/@$timestamp"
        fi

        ${lib.optionalString cfg.prune (pruneScript {
          dir = "$root";
          glob = "@[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]";
          inherit (cfg.retention) keepLast hourly daily weekly monthly;
        })}

        bcachefs subvolume snapshot "$root/@blank" "$root/@live"

        umount "$mnt"
        rmdir "$mnt"
      '';
    };
  };
}
