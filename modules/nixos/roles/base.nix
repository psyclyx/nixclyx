{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.roles.base;
in

{
  options = {
    psyclyx.roles.base = {
      enable = mkEnableOption "role for baseline config, likely applicable to all hosts";
    };
  };

  config = mkIf cfg.enable {
    psyclyx = {
      programs = {
        zsh.enable = mkDefault true;
      };

      system = {
        containers.enable = mkDefault true;
        documentation.enable = mkDefault true;
        home-manager.enable = mkDefault true;
        locale.enable = mkDefault true;
        nix.enable = mkDefault true;
        nixpkgs.enable = mkDefault true;
        timezone.enable = mkDefault true;
      };
    };
  };
}
