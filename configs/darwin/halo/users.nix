{ pkgs, ... }:
let
  userName = "psyc";
  userHome = "/Users/psyc";
  mkHome = import ../../../modules/home;
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

  home-manager.users.psyc = mkHome {
    name = userName;
    email = "me@psyclyx.xyz";
    modules = [
      ../../../modules/home/base
      ../../../modules/home/secrets
      ../../../modules/home/programs/emacs
      ../../../modules/home/programs/kitty.nix
      ../../../modules/home/programs/alacritty.nix
      ../../../modules/home/programs/signal.nix
      ../../../modules/home/programs/zsh.nix
      ../../../modules/home/services/postgres.nix
    ];
  };

  system.primaryUser = userName;

  nix-homebrew.user = userName;
}
