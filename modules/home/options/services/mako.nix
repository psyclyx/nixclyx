{
  path = ["psyclyx" "home" "services" "mako"];
  description = "Mako notification daemon";
  config = {pkgs, ...}: {
    home.packages = [pkgs.notify-desktop];
    services.mako = {
      enable = true;
      settings = {
        actions = true;
        anchor = "top-right";
        border-radius = 6;
        border-size = 4;
        default-timeout = 10000;
      };
    };
  };
}
