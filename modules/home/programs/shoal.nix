{
  path = ["psyclyx" "home" "programs" "shoal"];
  description = "Shoal wayland desktop shell toolkit";
  config = { pkgs, ... }: {
    programs.shoal = {
      enable = true;
      package = pkgs.psyclyx.shoal;
    };
  };
}
