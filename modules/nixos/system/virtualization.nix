{
  config,
  pkgs,
  lib,
  ...
}:
let
  emulatedSystems = {
    "x86_64-linux" = [ "aarch64-linux" ];
    "aarch64-linux" = [ "x86_64-linux" ];
    "aarch64-darwin" = [ "x86_64-darwin" ];
  };

  cfg = config.psyclyx.system.virtualization;
in
{
  options = {
    psyclyx.system.virtualization = {
      enable = lib.mkEnableOption "Enable virtualization.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.binfmt.emulatedSystems = emulatedSystems."${pkgs.system}" or { };
    virtualisation.docker.enable = true;
  };
}
