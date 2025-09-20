{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.system.emulation;
  defaultSystems = {
    "x86_64-linux" = [ "aarch64-linux" ];
    "aarch64-linux" = [ "x86_64-linux" ];
    "aarch64-darwin" = [ "x86_64-darwin" ];
  };
in
{
  options = {
    psyclyx.system.emulation = {
      enable = lib.mkEnableOption "Architecture emulation config";
      emulatedSystems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = defaultSystems."${pkgs.system}" or [ ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.binfmt.emulatedSystems = cfg.emulatedSystems;
  };
}
