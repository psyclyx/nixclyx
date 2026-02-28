{
  path = ["psyclyx" "nixos" "services" "chrony"];
  description = "chrony NTP client";
  config = _: {
    services.chrony.enable = true;
    services.timesyncd.enable = false;
  };
}
