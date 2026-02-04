{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.darwin.config.users.psyc.base;
in {
  options.psyclyx.darwin.config.users.psyc.base = {
    enable = lib.mkEnableOption "psyc base darwin user";
  };

  config = lib.mkIf cfg.enable {
    users.users.psyc = {
      name = "psyc";
      home = "/Users/psyc";
      uid = 501;
      shell = pkgs.zsh;
    };

    system.primaryUser = "psyc";

    nix-homebrew.user = "psyc";

    home-manager.users.psyc.psyclyx.home.config.darwin.enable = true;
  };
}
