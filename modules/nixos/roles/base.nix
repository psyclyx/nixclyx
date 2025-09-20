{
  config,
  lib,
  pkgs,
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
      system = {
        home-manager.enable = lib.mkDefault true;
        locale.enable = lib.mkDefault true;
        nix.enable = lib.mkDefault true;
        nixpkgs.enable = lib.mkDefault true;
      };
    };
  };
}
