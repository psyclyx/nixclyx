# Egregore → ZFS zvol provisioning projection.
#
# For each `lun` entity this host produces, emit a pair of
# Type=oneshot systemd units:
#
#   zfs-create@<lun>.service  — `zfs create -V <size> <dataset>`,
#     gated by `ConditionPathExists=!/dev/zvol/<dataset>` so it's
#     a no-op after first boot.
#
#   zfs-format@<lun>.service  — `mkfs.<fsType> -L <name> /dev/zvol/<ds>`,
#     `After=`/`Requires=` the device unit that udev brings up when
#     the zvol appears. ConditionPathExists guards against rerunning
#     mkfs over a populated filesystem (the device-unit dependency
#     does the wait — no shell-level polling).
#
# Consumers (microvm guests, iscsi targets) depend on the produced
# device units in turn, so the whole graph composes cleanly.
{ config, lib, pkgs, ... }:
let
  cfg = config.psyclyx.nixos.derived.zvol-provision;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = cfg.enable && hostname != "";

  myLuns = lib.filterAttrs (
    _: e:
    e.type == "lun"
    && (e.refs.producer or null) == hostname
    && e.attrs.dataset != null
  ) eg.entities;

  # systemd-escape for /dev/zvol/<dataset> → device unit name.
  # Rule: each `-` in the path becomes `\x2d`, each `/` becomes `-`.
  escapePathSegment = s: lib.replaceStrings [ "-" ] [ "\\x2d" ] s;
  systemdEscapePath =
    path:
    let
      stripped = lib.removePrefix "/" path;
    in
    lib.concatStringsSep "-" (map escapePathSegment (lib.splitString "/" stripped));

  zvolDeviceUnit = ds: "${systemdEscapePath "dev/zvol/${ds}"}.device";

  mkCreateUnit =
    lunName: lun:
    let
      ds = lun.attrs.dataset;
      size = "${toString lun.lun.sizeGiB}G";
    in
    {
      description = "Create zvol ${ds}";
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-import.target" ];
      requires = [ "zfs-import.target" ];
      # Skip if the dataset already exists. Asking ZFS directly is
      # the authoritative check; `/dev/zvol/...` symlinks are
      # populated by udev asynchronously after `zfs-import.target`
      # completes, so a path-existence guard races udev on a fresh
      # boot and fires `zfs create` against an already-present
      # dataset.
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecCondition = "${pkgs.bash}/bin/bash -c '! ${pkgs.zfs}/bin/zfs list -H -o name ${lib.escapeShellArg ds} >/dev/null 2>&1'";
      };
      path = [ pkgs.zfs ];
      script = ''
        zfs create -V ${lib.escapeShellArg size} ${lib.escapeShellArg ds}
      '';
    };

  mkFormatUnit =
    lunName: lun:
    let
      ds = lun.attrs.dataset;
      fsType = lun.lun.fsType;
      deviceUnit = zvolDeviceUnit ds;
    in
    {
      description = "Format zvol ${ds} as ${fsType}";
      wantedBy = [ "multi-user.target" ];
      # Wait for the device unit udev creates once the zvol exists.
      # No shell-level polling — systemd holds activation until the
      # device target's `active` state is reached (or timeout).
      after = [ "zfs-create-${lunName}.service" deviceUnit ];
      requires = [ "zfs-create-${lunName}.service" deviceUnit ];
      bindsTo = [ deviceUnit ];
      # Skip if the device already carries a filesystem of any type.
      # `blkid -p` exits 0 when it can identify a FS, non-zero
      # otherwise; we want non-zero (no FS yet) for the unit to
      # proceed. `!` inverts the exit code.
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecCondition = "${pkgs.bash}/bin/bash -c '! ${pkgs.util-linux}/bin/blkid -p -o export /dev/zvol/${ds} | ${pkgs.gnugrep}/bin/grep -q ^TYPE='";
      };
      path = [ pkgs.e2fsprogs ];
      script = ''
        case ${lib.escapeShellArg fsType} in
          ext4) mkfs.ext4 -L ${lib.escapeShellArg lunName} /dev/zvol/${ds} ;;
          *)    echo "unknown fsType ${fsType} for ${ds}" >&2 ; exit 1 ;;
        esac
      '';
    };

  createUnits = lib.mapAttrs' (
    lunName: lun: lib.nameValuePair "zfs-create-${lunName}" (mkCreateUnit lunName lun)
  ) myLuns;

  formatUnits = lib.mapAttrs' (
    lunName: lun: lib.nameValuePair "zfs-format-${lunName}" (mkFormatUnit lunName lun)
  ) myLuns;
in
{
  options.psyclyx.nixos.derived.zvol-provision = {
    enable = lib.mkEnableOption ''
      project this host's `lun` entities into per-zvol create +
      mkfs systemd units. The unit graph uses systemd's own
      `dev-zvol-…device` dependencies for the create/format
      ordering, so no scripts block waiting for devices.
    '';
  };

  config = lib.mkIf enabled {
    systemd.services = createUnits // formatUnits;
  };
}
