{
  path = ["psyclyx" "home" "programs" "shoal"];
  description = "Shoal wayland surface renderer";
  config = { pkgs, ... }: {
    programs.shoal = {
      enable = true;
      package = pkgs.psyclyx.shoal;

      surfaces.bar = {
        layer = "top";
        height = 36;
        exclusive_zone = 40;
        margin = { top = 4; left = 6; right = 6; };

        modules_left = [ "workspaces" "minimap" ];
        modules_center = [ "signal" "title" ];
        modules_right = [ "pulseaudio" "network" "cpu" "memory" "clock" ];
        clock_format = "%I:%M %p";
      };
    };
  };
}
