{
  path = ["psyclyx" "nixos" "services" "kanata"];
  description = "Kanata (keyboard remapper)";
  config = _: {
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
