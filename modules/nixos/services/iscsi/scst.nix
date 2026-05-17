# SCST iSCSI target service.
#
# Declarative configuration of iSCSI targets backed by block devices
# (typically ZFS zvols). The `psyclyx.nixos.topology.iscsi` projection
# populates `targets` from egregore `lun` entities; hosts shouldn't
# normally set `targets` directly.
#
# Generates /etc/scst.conf in a config-file format SCST consumes via
# `scstadmin -config`. The kernel module + scstadmin tool come from the
# `scst` package (currently a stub — see nixclyx/packages/scst/default.nix).
{
  path = ["psyclyx" "nixos" "services" "iscsi" "scst"];
  description = "SCST iSCSI target subsystem";

  options = {lib, pkgs, ...}: {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.scst;
      description = "SCST package providing kernel modules and scstadmin.";
    };

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
      description = "IP addresses the iSCSI portal binds to.";
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
                    blockSize = lib.mkOption { type = lib.types.int; default = 4096; };
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
    mkDeviceBlock = name: lunSpec: ''
      DEVICE ${name}_lun${toString lunSpec.lun} {
        filename ${lunSpec.device}
        blocksize ${toString lunSpec.blockSize}
        ${lib.optionalString lunSpec.readOnly "read_only 1"}
      }
    '';

    mkLunLine = name: lunSpec:
      "      LUN ${toString lunSpec.lun} ${name}_lun${toString lunSpec.lun}";

    mkAclLine = iqn: ''        INITIATOR_NAME "${iqn}"'';

    mkTargetBlock = name: t: ''
      TARGET ${t.iqn} {
        rel_tgt_id ${toString (lib.stringLength t.iqn)}
        enabled 1

        GROUP allowed-initiators {
${lib.concatMapStringsSep "\n" mkAclLine t.aclIqns}

${lib.concatMapStringsSep "\n" (mkLunLine name) t.luns}
        }
      }
    '';

    devicesBlock = lib.concatStrings (
      lib.mapAttrsToList (n: t:
        lib.concatMapStrings (mkDeviceBlock n) t.luns
      ) cfg.targets
    );

    targetsBlock = lib.concatStrings (
      lib.mapAttrsToList mkTargetBlock cfg.targets
    );

    portalAddresses = lib.concatMapStringsSep " " (p: p.address) cfg.portals;

    scstConf = pkgs.writeText "scst.conf" ''
      HANDLER vdisk_fileio {
${devicesBlock}
      }

      TARGET_DRIVER iscsi {
        enabled 1
        IncomingUser ""
${lib.optionalString (portalAddresses != "") "        portal ${portalAddresses}"}

${targetsBlock}
      }
    '';
  in lib.mkIf (cfg.targets != {}) {
    boot.extraModulePackages = [ cfg.package ];

    environment.etc."scst.conf".source = scstConf;
    environment.systemPackages = [ cfg.package ];

    systemd.services.scst = {
      description = "SCST iSCSI target subsystem";
      after = [ "zfs-import.target" "network.target" ];
      wants = [ "zfs-import.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = [
          "${pkgs.kmod}/bin/modprobe scst"
          "${pkgs.kmod}/bin/modprobe scst_vdisk"
          "${pkgs.kmod}/bin/modprobe iscsi-scst"
        ];
        ExecStart = "${cfg.package}/bin/scstadmin -force -no_prompt -config /etc/scst.conf";
        ExecStop = "${cfg.package}/bin/scstadmin -force -no_prompt -clear_config";
      };
    };

    psyclyx.nixos.network.ports.iscsi.tcp = [ 3260 ];
  };
}
