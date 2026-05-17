# Open-iSCSI initiator for runtime LUN attachments.
#
# Wraps nixpkgs' `services.openiscsi`. The `psyclyx.nixos.topology.iscsi`
# projection populates `mounts` from `lun` entities whose `consumers`
# include this host.
#
# All mounts are runtime — host root never comes from iSCSI (we PXE-boot),
# so there's no initramfs hook. This module handles VM disk and data LUNs
# attached after systemd is up.
{
  path = ["psyclyx" "nixos" "services" "iscsi" "initiator"];
  description = "Open-iSCSI initiator for runtime LUN mounts";

  options = {lib, ...}: {
    initiatorIqn = lib.mkOption {
      type = lib.types.str;
      description = "This host's iSCSI IQN.";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            targetIqn = lib.mkOption { type = lib.types.str; };
            portals = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Portal IP addresses for the target.";
            };
            lun = lib.mkOption { type = lib.types.int; default = 0; };
            mountpoint = lib.mkOption {
              type = lib.types.str;
              description = "Where to mount the attached block device.";
            };
            fsType = lib.mkOption {
              type = lib.types.str;
              default = "ext4";
            };
            options = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
            };
          };
        }
      );
      default = {};
    };
  };

  config = {cfg, lib, ...}: lib.mkIf (cfg.mounts != {}) {
    services.openiscsi = {
      enable = true;
      name = cfg.initiatorIqn;
    };

    fileSystems = lib.mapAttrs' (_name: mount:
      lib.nameValuePair mount.mountpoint {
        device = "/dev/disk/by-path/ip-${lib.head mount.portals}:3260-iscsi-${mount.targetIqn}-lun-${toString mount.lun}";
        fsType = mount.fsType;
        options = [ "_netdev" "nofail" "x-systemd.device-timeout=30s" ] ++ mount.options;
      }
    ) cfg.mounts;
  };
}
