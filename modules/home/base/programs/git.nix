{ config, lib, ... }:
{
  programs.git = {
    enable = lib.mkDefault true;
    userName = lib.mkDefault config.my.user.name;
    userEmail = lib.mkDefault config.my.user.email;
    iniContent = lib.mkMerge [
      {
        "pull" = {
          "rebase" = true;
        };
        "core" = {
          "fsmonitor" = true;
        };
      }
    ];
  };
}
