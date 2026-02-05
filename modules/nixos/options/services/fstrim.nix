{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "fstrim"];
  description = "TRIM daemon for SSDs";
  config = _: {
    services.fstrim.enable = true;
  };
} args
