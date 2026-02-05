{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "fwupd"];
  description = "fwupd";
  config = _: {
    services.fwupd.enable = true;
  };
} args
