{
  path = ["psyclyx" "nixos" "filesystems" "impermanence"];
  description = "bcachefs root impermanence (wipe-on-boot)";
  options = {lib, ...}: {
    device = lib.mkOption {
      type = lib.types.str;
      description = "bcachefs device path (e.g. /dev/disk/by-partlabel/nvme0-root)";
    };

    subvolume = lib.mkOption {
      type = lib.types.str;
      default = "subvolumes/root";
      description = "Path within bcachefs to the root subvolume group (containing @blank and @live)";
    };

    retention = {
      keepLast = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Always keep at least this many old roots regardless of age";
      };

      hourly = lib.mkOption {
        type = lib.types.int;
        default = 6;
        description = "Number of hourly snapshots to keep";
      };

      daily = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Number of daily snapshots to keep";
      };

      weekly = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Number of weekly snapshots to keep";
      };

      monthly = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Number of monthly snapshots to keep";
      };
    };
  };

  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    pruneScript = import ../../../lib/bcachefs-prune.nix {inherit lib;};
  in {
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

        # Preserve current root as a timestamped snapshot
        if [ -d "$root/@live" ]; then
          mv "$root/@live" "$root/@$timestamp"
        fi

        # Prune old roots
        ${pruneScript {
          dir = "$root";
          glob = "@2*";
          inherit (cfg.retention) keepLast hourly daily weekly monthly;
        }}

        # Restore from blank
        bcachefs subvolume snapshot "$root/@blank" "$root/@live"

        umount "$mnt"
        rmdir "$mnt"
      '';
    };
  };
}
