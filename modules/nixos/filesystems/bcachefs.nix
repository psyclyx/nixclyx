{
  path = ["psyclyx" "nixos" "filesystems" "bcachefs"];
  description = "bcachefs";
  extraOptions = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.psyclyx.nixos.filesystems.bcachefs;

    getDeviceUnit = {bindsTo ? [], ...}:
      lib.findFirst (lib.hasSuffix ".device") null bindsTo;

    # Unescape a systemd device unit name back to a device path.
    # e.g. "dev-disk-by\\x2dpartlabel-nvme0\\x2droot" -> "/dev/disk/by-partlabel/nvme0-root"
    #
    # Systemd escaping: "/" -> "-", literal "-" -> "\\x2d".
    # Reverse: protect literal hyphens, convert separators, restore hyphens.
    unescapeDevicePath = escaped: let
      protected = builtins.replaceStrings ["\\x2d"] ["\x00"] escaped;
      withSlashes = builtins.replaceStrings ["-"] ["/"] protected;
      restored = builtins.replaceStrings ["\x00"] ["-"] withSlashes;
    in
      "/" + restored;

    bcachefsUnlockSubmodule = systemdPkg: {
      name,
      config,
      ...
    }: {
      config = lib.mkIf (cfg.enable && lib.hasPrefix "unlock-bcachefs-" name) (
        let
          deviceUnit = getDeviceUnit config;
          escaped = lib.removeSuffix ".device" deviceUnit;
          targetName = "bcachefs-unlocked@${escaped}";
          devicePath = unescapeDevicePath escaped;
        in
          lib.mkIf (deviceUnit != null) {
            conflicts = ["${targetName}.target"];
            unitConfig.OnSuccess = ["${targetName}.target"];
            serviceConfig.KeyringMode = "inherit";
            serviceConfig.ExecCondition = lib.mkForce
              "${pkgs.writeShellScript "check-bcachefs-needs-unlock-${escaped}" ''
                ! ${pkgs.bcachefs-tools}/bin/bcachefs mount -k fail ${lib.escapeShellArg devicePath} 2>/dev/null
              ''}";
          }
      );
    };
  in {
    boot.initrd.systemd.services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (bcachefsUnlockSubmodule config.boot.initrd.systemd.package)
      );
    };

    systemd.services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (bcachefsUnlockSubmodule pkgs.systemd));
    };
  };
  config = _: {
    boot.supportedFilesystems = ["bcachefs"];

    boot.initrd.systemd.targets."bcachefs-unlocked@" = {
      conflicts = ["shutdown.target"];
      unitConfig.DefaultDependencies = false;
    };

    systemd.targets."bcachefs-unlocked@" = {
      conflicts = ["shutdown.target"];
      unitConfig.DefaultDependencies = false;
    };
  };
}
