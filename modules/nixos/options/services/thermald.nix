{
  path = ["psyclyx" "nixos" "services" "thermald"];
  description = "thermal throttling daemon for intel cpus";
  config = _: {
    services.thermald.enable = true;
  };
}
