{
  config,
  lib,
  ...
}:
let
  cfgEnabled = config.psyclyx.roles.dev;
in
{
  options = {
    psyclyx = {
      roles = {
        dev = lib.mkEnableOption "dev tools/config";
      };
    };
  };

  config = lib.mkIf cfgEnabled {
    psyclyx = {
      programs = {
        git = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
}
