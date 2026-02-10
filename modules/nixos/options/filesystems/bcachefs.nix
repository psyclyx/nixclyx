{
  path = ["psyclyx" "nixos" "filesystems" "bcachefs"];
  description = "bcachefs";
  gate = false;
  extraOptions = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.psyclyx.nixos.filesystems.bcachefs;

    getDeviceUnit = {bindsTo ? [], ...}:
      lib.findFirst (lib.hasSuffix ".device") null bindsTo;

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
        in
          lib.mkIf (deviceUnit != null) {
            conflicts = ["${targetName}.target"];
            unitConfig.OnSuccess = ["${targetName}.target"];
            serviceConfig.ExecCondition = lib.mkForce ''
              !${pkgs.bcachefs-tools}/bin/bcachefs mount -k fail "$(${systemdPkg}/bin/systemd-escape --unescape --path "${escaped}")"
            '';
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
