{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.services.kanata;
in {
  options = {
    psyclyx.nixos.services.kanata = {
      enable = lib.mkEnableOption "Kanata (keyboard remapper)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.kanata = {
      enable = true;
      keyboards.default = {
        config = builtins.readFile ./keyboard.kbd;
        extraDefCfg = ''
          process-unmapped-keys yes
          danger-enable-cmd yes
          sequence-timeout 2000
          sequence-input-mode visible-backspaced
          log-layer-changes no
        '';
      };
    };
  };
}
