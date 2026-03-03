{
  path = ["psyclyx" "home" "programs" "shoal"];
  description = "Shoal wayland surface renderer";
  config = { pkgs, ... }: {
    programs.shoal = {
      enable = true;
      package = pkgs.psyclyx.shoal;
    };
  };
}
