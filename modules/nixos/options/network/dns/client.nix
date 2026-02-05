{
  path = ["psyclyx" "nixos" "network" "dns" "client"];
  description = "avahi+systemd-resolved";
  config = _: {
    psyclyx.nixos.services = {
      avahi.enable = true;
      resolved.enable = true;
    };
  };
}
