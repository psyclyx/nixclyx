{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.home.config.base;
in {
  options.psyclyx.home.config.base = {
    enable = lib.mkEnableOption "psyc base home config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      home = {
        info = {
          name = "psyclyx";
          email = "me@psyclyx.xyz";
        };

        programs = {
          fastfetch.enable = true;
          git.enable = true;
        };

        roles = {
          shell.enable = true;
        };

        xdg.enable = true;
      };
    };
  };
}
