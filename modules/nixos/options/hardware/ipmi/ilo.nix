{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "hardware" "ipmi" "ilo"];
  description = "HPE Integrated Lights Out";
  config = _: {
    boot.initrd.availableKernelModules = ["hpilo"];
  };
} args
