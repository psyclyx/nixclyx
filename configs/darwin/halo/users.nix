{ pkgs, ... }:
let
  userName = "psyc";
  userHome = "/Users/psyc";
in
{
  config = {
    users.users.psyc = {
      name = userName;
      home = userHome;
      uid = 501;
      shell = pkgs.zsh;
    };

    system.primaryUser = userName;

    nix-homebrew.user = userName;

    home-manager.users.psyc = {
      imports = [ ../../home/psyc.nix ];
      psyclyx.configs.psyc = {
        enable = true;
        secrets = true;
      };
    };
  };
}
