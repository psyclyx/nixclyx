{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "avahi"];
  description = "Service discovery / MDNS";
  config = _: {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish.enable = true;
    };
  };
} args
