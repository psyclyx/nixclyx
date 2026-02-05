{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "sddm"];
  description = "Simple Desktop Display Manager";
  config = _: {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  };
} args
