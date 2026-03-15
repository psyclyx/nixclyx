{
  path = ["psyclyx" "nixos" "services" "gdm"];
  description = "GNOME Display Manager";
  config = _: {
    services.displayManager.gdm = {
      enable = true;
    };
  };
}
