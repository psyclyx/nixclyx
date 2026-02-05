{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "network" "wireless"];
  description = "wireless network support";
  config = _: {
    networking.wireless.iwd = {
      enable = true;
      settings.Settings.AutoConnect = true;
    };
  };
} args
