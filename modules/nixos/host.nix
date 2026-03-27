{
  path = ["psyclyx" "nixos"];
  gate = "always";
  options = {
    lib,
    config,
    ...
  }: {
    host = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Canonical hostname. Defaults to networking.hostName.";
    };
  };
}
