{
  path = ["psyclyx" "home" "programs" "vanish"];
  description = "Lightweight terminal session multiplexer built on libghostty";
  config = {
    pkgs,
    config,
    ...
  }: let
    vanishConfig = {
      leader = "Ctrl+Space";
      serve = {
        bind = "127.0.0.1";
        port = 7890;
        auto_serve = true;
      };
    };
  in {
    home.packages = [pkgs.vanish];
    home.file."${config.xdg.configHome}/vanish/config.json".text = builtins.toJSON vanishConfig;
  };
}
