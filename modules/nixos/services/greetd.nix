{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.services.greetd;
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
in
{
  options = {
    psyclyx = {
      services = {
        greetd = {
          enable = lib.mkEnableOption "Enable greetd greeter.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      greetd = {
        enable = true;
        vt = 2;
        settings = {
          default_session = {
            command = "${tuigreet} --time --user-menu --remember --asterisks --cmd sway";
          };
          user = "greeter";
        };
      };
    };
  };
}
