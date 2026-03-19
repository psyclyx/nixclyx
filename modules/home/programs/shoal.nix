{
  path = ["psyclyx" "home" "programs" "shoal"];
  description = "Shoal wayland desktop shell toolkit";
  config = { pkgs, ... }: {
    programs.shoal = {
      enable = true;
      package = pkgs.psyclyx.shoal;

      surfaces.bar = {
        layer = "top";
        height = 36;
        exclusive_zone = 40;
        margin = { top = 4; left = 6; right = 6; };
      };
    };
  };
}
