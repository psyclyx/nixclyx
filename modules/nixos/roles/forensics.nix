{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.roles.forensics;
in
{
  options = {
    psyclyx.roles.forensics = {
      enable = mkEnableOption "Digital forensics software";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      hashcat
      john
      libxcrypt
      sleuthkit
      wordlists
    ];
  };
}
