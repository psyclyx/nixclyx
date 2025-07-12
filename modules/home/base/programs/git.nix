{ config, lib, ... }:
{
  # deprecated
  programs.git = {
    enable = lib.mkDefault true;
    userName = lib.mkDefault config.psyclyx.user.name;
    userEmail = lib.mkDefault config.psyclyx.user.email;
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
