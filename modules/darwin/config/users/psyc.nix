{
  path = ["psyclyx" "darwin" "config" "users" "psyc"];
  description = "psyc darwin user";
  config = {lib, pkgs, ...}: {
    users.users.psyc = {
      name = "psyc";
      home = "/Users/psyc";
      uid = 501;
      shell = pkgs.zsh;
    };

    system.primaryUser = "psyc";

    nix-homebrew.user = "psyc";

    home-manager.users.psyc = {
      psyclyx.home.config.homes.psyc.base.enable = true;
      psyclyx.home.variant = "darwin";
    };
  };
}
