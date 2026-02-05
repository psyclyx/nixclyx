{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "boot" "systemd" "loader"];
  description = "systemd-boot";
  config = _: {
    boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          configurationLimit = 8;
          consoleMode = "max";
        };

        timeout = 1;
      };
    };
  };
} args
