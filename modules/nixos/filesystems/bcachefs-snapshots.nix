{
  path = ["psyclyx" "nixos" "filesystems" "bcachefs-snapshots"];
  description = "periodic bcachefs subvolume snapshots";
  options = {lib, ...}: {
    targets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "bcachefs device path";
          };

          subvolume = lib.mkOption {
            type = lib.types.str;
            description = "Path within bcachefs to the subvolume group (containing @live)";
          };

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "*:0/10";
            description = "systemd calendar expression for snapshot frequency";
          };

          retention = {
            keepLast = lib.mkOption {
              type = lib.types.int;
              default = 3;
              description = "Always keep at least this many snapshots regardless of age";
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
              default = 6;
              description = "Number of monthly snapshots to keep";
            };
          };
        };
      });
      default = {};
      description = "Subvolumes to snapshot periodically";
    };
  };

  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    pruneScript = import ../../../lib/bcachefs-prune.nix {inherit lib;};

    mkSnapshotUnits = name: target: {
      services."bcachefs-snapshot-${name}" = {
        description = "Snapshot bcachefs subvolume: ${name}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = let
            script = pkgs.writeShellScript "bcachefs-snapshot-${name}" ''
              set -euo pipefail
              mnt=$(mktemp -d /run/bcachefs-snapshot-${name}.XXXXXX)
              mount -t bcachefs ${lib.escapeShellArg target.device} "$mnt"

              snap_dir="$mnt/${lib.escapeShellArg target.subvolume}/@snapshots"
              mkdir -p "$snap_dir"
              timestamp=$(date +%Y-%m-%dT%H:%M:%S)
              bcachefs subvolume snapshot -r \
                "$mnt/${lib.escapeShellArg target.subvolume}/@live" \
                "$snap_dir/$timestamp"

              # Prune old snapshots
              ${pruneScript {
                dir = "$snap_dir";
                glob = "2*";
                inherit (target.retention) keepLast hourly daily weekly monthly;
              }}

              umount "$mnt"
              rmdir "$mnt"
            '';
          in "${script}";
        };
      };

      timers."bcachefs-snapshot-${name}" = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = target.calendar;
          Persistent = true;
        };
      };
    };
  in {
    systemd = lib.mkMerge (lib.mapAttrsToList mkSnapshotUnits cfg.targets);
  };
}
