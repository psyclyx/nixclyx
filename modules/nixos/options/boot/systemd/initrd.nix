{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "boot" "systemd" "initrd"];
  description = "systemd initrd";
  config = _: {
    boot.initrd = {
      systemd = {
        enable = true;
        emergencyAccess = true;
        network.enable = true;
      };
    };
  };
} args
