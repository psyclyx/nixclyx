{
  path = ["psyclyx" "nixos" "services" "gdm"];
  description = "GNOME DIsplay Manager";
  config = _: {
    services.displayManager.gdm = {
      enable = true;
    };
  };
}
