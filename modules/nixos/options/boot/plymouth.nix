{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "boot" "plymouth"];
  description = "graphical startup";
  config = _: {
    boot = {
      plymouth.enable = true;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
      ];
    };
  };
} args
