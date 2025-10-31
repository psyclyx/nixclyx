{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.psyclyx.users.psyc;
in
{
  options.psyclyx.users.psyc = {
    enable = lib.mkEnableOption "psyc hm preset";
    extraModules = lib.mkOption { default = { }; };
  };

  config = lib.mkIf cfg.enable {
    imports = [ cfg.extraModules ];

    config = {
      home.stateVersion = "25.05";
      psyclyx = {
        roles.shell.enable = true;
        user = {
          name = "psyclyx";
          email = "me@psyclyx.xyz";
        };
      };
    };
  };
}
