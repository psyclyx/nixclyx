{
  path = ["psyclyx" "home" "config" "homes" "psyc" "darwin"];
  variant = ["psyclyx" "home" "variant"];
  config = {lib, ...}: {
    psyclyx.home.programs.kitty.enable = true;
  };
}
