{ config, lib, ... }:
let
  cfg = config.psyclyx.system.console;
in
{
  options = {
    psyclyx = {
      system = {
        console = {
          enable = lib.mkEnableOption "Set up the console.";
        };
      };
    };

  };

  config = lib.mkIf cfg.enable {
    console = {
      earlySetup = true;
      font = "Lat2-Terminus16";
      keyMap = "us";
    };
  };
}
