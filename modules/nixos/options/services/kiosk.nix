{
  path = ["psyclyx" "nixos" "services" "kiosk"];
  description = "Cage Wayland kiosk";
  options = {lib, ...}: {
    url = lib.mkOption {
      type = lib.types.str;
      description = "URL to display in the kiosk.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "kiosk";
      description = "User to autologin as.";
    };
  };
  config = {
    cfg,
    pkgs,
    ...
  }: let
    domain = builtins.head (builtins.match "https?://([^/:]+).*" cfg.url);
  in {
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      home = "/var/lib/${cfg.user}";
      createHome = true;
    };
    users.groups.${cfg.user} = {};

    services.cage = {
      enable = true;
      inherit (cfg) user;
      program = "${pkgs.firefox}/bin/firefox --kiosk=${cfg.url}";
      environment = {"WLR_LIBINPUT_NO_DEVICES" = "1";};
    };
  };
}
