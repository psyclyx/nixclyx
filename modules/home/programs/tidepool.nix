{
  path = ["psyclyx" "home" "programs" "tidepool"];
  description = "Tidepool window manager";
  config = { config, pkgs, ... }: {
    services.tidepool = {
      enable = true;
      package = pkgs.psyclyx.tidepool;
      wallpaper = config.stylix.image;
    };
  };
}
