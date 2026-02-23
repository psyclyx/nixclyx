{
  path = ["psyclyx" "home" "profiles" "psyc" "darwin"];
  description = "psyc darwin-specific home config";
  config = {lib, ...}: {
    psyclyx.home.programs.kitty.enable = true;
  };
}
