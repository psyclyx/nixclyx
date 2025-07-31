{ inputs, pkgs, ... }:
let
  userName = "psyc";
  userHome = "/Users/psyc";
in
{
  nix.settings.trusted-users = [
    "root"
    "@admin"
    userName
  ];

  users.users.psyc = {
    name = userName;
    home = userHome;
    uid = 501;
    shell = pkgs.zsh;
  };

  home-manager.users.psyc = (import ../../home/psyc.nix).darwinDesktop;

  system.primaryUser = userName;
  nix-homebrew.user = userName;
}
