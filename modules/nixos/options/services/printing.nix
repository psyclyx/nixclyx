{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "services" "printing"];
  description = "Enable printing.";
  config = _: {
    services.printing = {
      enable = true;
      drivers = [pkgs.brlaser];
    };
  };
} args
