{ config, lib, ... }:
let
  cfg = config.psyclyx.services.kanata;
in
{
  options = {
    psyclyx = {
      services = {
        kanata = {
          enable = lib.mkEnableOption "Kanata (keyboard remapper)";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services = {
      kanata = {
        enable = true;
        keyboards = {
          default = {
            extraDefCfg = ''
              process-unmapped-keys yes
              danger-enable-cmd yes
              sequence-timeout 2000
              sequence-input-mode visible-backspaced
              log-layer-changes no
            '';
            config = builtins.readFile ./keyboard.kbd;
          };
        };
      };
    };
  };
}
