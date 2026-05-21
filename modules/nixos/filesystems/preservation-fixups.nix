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
  };
}
