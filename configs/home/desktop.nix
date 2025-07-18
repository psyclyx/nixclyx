{ pkgs, ... }:
{
  psyclyx = {
    roles = {
      shell = true;
      dev = true;
      graphical = true;
      sway = pkgs.stdenv.isLinux;
    };
    secrets = {
      enable = true;
    };
  };
}
