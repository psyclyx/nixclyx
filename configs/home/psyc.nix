{ config, lib, ... }:
let
  cfg = config.psyclyx.configs.psyc;
in
{
  options.psyclyx.configs.psyc = {
    enable = lib.mkEnableOption "psyc hm preset";
    secrets = lib.mkEnableOption "secrets";
    server = lib.mkEnableOption "server";
  };
  config = lib.mkIf cfg.enable {
    home.stateVersion = "25.05";
    psyclyx = {
      user.name = "psyclyx";
      user.email = "me@psyclyx.xyz";
      roles = rec {
        shell = true;
        dev = !cfg.server;
        graphical = !cfg.server;
      };
      secrets.enable = cfg.secrets;
    };
  };
}
