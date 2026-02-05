{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "resolved"];
  description = "systemd-resolved dns resolver";
  config = _: {
    services.resolved = {
      enable = true;
      settings.Resolve = {
        MulticastDNS = false;
      };
    };
  };
} args
