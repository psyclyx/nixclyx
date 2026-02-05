{
  path = ["psyclyx" "nixos" "services" "fwupd"];
  description = "fwupd";
  config = _: {
    services.fwupd.enable = true;
  };
}
