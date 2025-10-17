{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.roles.base;
in

{
  options = {
    psyclyx.roles.base = {
      enable = lib.mkEnableOption "role for baseline config, likely applicable to all hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      programs = {
        zsh.enable = lib.mkDefault true;
      };

      system = {
        documentation.enable = lib.mkDefault true;
        home-manager.enable = lib.mkDefault true;
        locale.enable = lib.mkDefault true;
        nix.enable = lib.mkDefault true;
        nixpkgs.enable = lib.mkDefault true;
        timezone.enable = lib.mkDefault true;
      };
    };
  };
}
