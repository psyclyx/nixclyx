{
  path = ["psyclyx" "nixos" "filesystems" "preservation-fixups"];
  gate = args: args.config.preservation.enable;
  config = _: {
    # Preservation bind-mounts /etc/machine-id from /persist, turning
    # it into a mount point. systemd-machine-id-commit then sees a
    # non-tmpfs /etc/machine-id and fails — but the bind-mount is
    # already on real disk, so there's nothing to commit. Disable the
    # unit whenever preservation is in play.
    systemd.services.systemd-machine-id-commit.enable = false;

    # netboot.nix's register-nix-paths.service loads the store DB
    # from /nix/store/nix-path-registration on every start. The file
    # is consumed on first boot and never re-staged, so the unit
    # fails on every subsequent activation. Skip when the file is
    # absent — the DB is already loaded, and the other steps
    # (touch /etc/NIXOS, set system profile) are idempotent.
    systemd.services.register-nix-paths.unitConfig.ConditionPathExists =
      "/nix/store/nix-path-registration";
  };
}
