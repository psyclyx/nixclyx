# LIO iSCSI target — kernel-native (Linux IO Target, in-tree since
# 2.6.38). Declarative wrapper that renders LIO's saveconfig.json and
# restores it at boot via targetctl.
#
# Fleet-agnostic. The topology/iscsi.nix projection feeds `targets`
# and `portals` from `lun` entities. Block-device backstores point at
# raw ZFS zvol paths (/dev/zvol/<pool>/<dataset>).
{
  path = ["psyclyx" "nixos" "services" "iscsi" "target"];
  description = "LIO iSCSI target (kernel-native; configured via targetctl)";

  options = {lib, ...}: {
    portals = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            address = lib.mkOption { type = lib.types.str; };
            network = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Egregore network name (metadata, for logs).";
            };
          };
        }
      );
      default = [];
      description = "IP addresses the target portal binds to.";
    };

    targets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            iqn = lib.mkOption { type = lib.types.str; };
            luns = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    device = lib.mkOption {
                      type = lib.types.str;
                      description = "Backing block device path.";
                    };
                    lun = lib.mkOption { type = lib.types.int; default = 0; };
                    readOnly = lib.mkOption { type = lib.types.bool; default = false; };
                  };
                }
              );
              default = [];
            };
            aclIqns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Initiator IQNs allowed to attach this target.";
            };
          };
        }
      );
      default = {};
    };
  };

  config = {cfg, lib, pkgs, ...}: let
    backstoreNameFor = targetName: lunIdx:
      "${targetName}_lun${toString lunIdx}";

    # Storage objects: one block backstore per LUN per target. The WWN
    # is a hash of the IQN + LUN index — stable across rebuilds, unique
    # per (target, lun) pair.
    storageObjects = lib.flatten (
      lib.mapAttrsToList (targetName: target:
        lib.imap0 (i: lunSpec: {
          name = backstoreNameFor targetName i;
          plugin = "block";
          dev = lunSpec.device;
          readonly = lunSpec.readOnly;
          attributes = { emulate_tpu = 1; };  # advertise SCSI UNMAP (discard)
          wwn = builtins.substring 0 25
            (builtins.hashString "sha256" "${target.iqn}/${toString lunSpec.lun}");
        }) target.luns
      ) cfg.targets
    );

    # targetcli expects `port`, not `iport`. The two appear in
    # different parts of LIO's history; nixpkgs' targetcli-fb takes
    # `port`.
    mkPortal = p: { ip_address = p.address; port = 3260; };

    mkTpg = targetName: target: {
      tag = 1;
      enable = true;
      attributes = {
        authentication = 0;
        generate_node_acls = 0;
        demo_mode_write_protect = 0;
      };
      portals = map mkPortal cfg.portals;
      luns = lib.imap0 (i: lunSpec: {
        index = lunSpec.lun;
        storage_object = "/backstores/block/${backstoreNameFor targetName i}";
      }) target.luns;
      node_acls = map (initiatorIqn: {
        node_wwn = initiatorIqn;
        mapped_luns = lib.imap0 (i: lunSpec: {
          index = lunSpec.lun;
          tpg_lun = lunSpec.lun;
          write_protect = lunSpec.readOnly;
        }) target.luns;
      }) target.aclIqns;
    };

    targetsJson = lib.mapAttrsToList (name: target: {
      fabric = "iscsi";
      wwn = target.iqn;
      tpgs = [ (mkTpg name target) ];
    }) cfg.targets;

    saveConfig = pkgs.writeText "saveconfig.json" (builtins.toJSON {
      fabric_modules = [
        { name = "iscsi"; discovery_auth = { authentication = 0; }; }
      ];
      storage_objects = storageObjects;
      targets = targetsJson;
    });
  in lib.mkIf (cfg.targets != {}) {
    environment.systemPackages = [ pkgs.targetcli-fb ];

    # LIO's kernel pieces. configfs is the runtime mount target backing
    # everything; target_core_mod is the core; target_core_iblock
    # handles raw block-device backstores (zvols look like blocks);
    # iscsi_target_mod is the iSCSI fabric.
    boot.kernelModules = [
      "configfs"
      "target_core_mod"
      "target_core_iblock"
      "iscsi_target_mod"
    ];

    systemd.tmpfiles.rules = [
      "d /etc/target 0700 root root -"
    ];

    environment.etc."target/saveconfig.json".source = saveConfig;

    # Upstream's `targetctl` is a small bash wrapper over targetcli's
    # `saveconfig` / `restoreconfig` / `clearconfig` subcommands.
    # nixpkgs' targetcli-fb derivation doesn't install it, so we drive
    # targetcli directly. Restore is also guarded against the
    # saveconfig.json not existing yet (first boot before any targets
    # are defined still triggers the unit via wantedBy=multi-user).
    systemd.services.target = let
      restoreScript = pkgs.writeShellScript "lio-target-restore" ''
        set -eu
        if [ ! -s /etc/target/saveconfig.json ]; then
          echo "no /etc/target/saveconfig.json — nothing to restore"
          exit 0
        fi
        exec ${pkgs.targetcli-fb}/bin/targetcli restoreconfig /etc/target/saveconfig.json
      '';
      clearScript = pkgs.writeShellScript "lio-target-clear" ''
        exec ${pkgs.targetcli-fb}/bin/targetcli clearconfig confirm=True
      '';
    in {
      description = "LIO iSCSI target restore";
      after = [ "zfs-import.target" "network.target" "sys-kernel-config.mount" ];
      wants = [ "zfs-import.target" "sys-kernel-config.mount" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.targetcli-fb ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.kmod}/bin/modprobe -a configfs target_core_mod target_core_iblock iscsi_target_mod";
        ExecStart = restoreScript;
        ExecStop = clearScript;
      };
    };

    psyclyx.nixos.network.ports.iscsi.tcp = [ 3260 ];
  };
}
