{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  inherit (pkgs.stdenv.hostPlatform) system;
  defaultSystems =
    {
      "x86_64-linux" = [ "aarch64-linux" ];
      "x86_64-darwin" = [ "aarch64-darwin" ];
      "aarch64-linux" = [ "x86_64-linux" ];
      "aarch64-darwin" = [ "x86_64-darwin" ];
    }
    .${system} or [ ];

  cfg = config.psyclyx.nixos.system.emulation;
in
{
  options = {
    psyclyx.nixos.system.emulation = {
      enable = mkEnableOption "Architecture emulation config";
      emulatedSystems = mkOption {
        type = types.listOf types.str;
        description = "Systems to emulate";
        example = [ "aarch64-linux" ];
        default = defaultSystems;
      };
    };
  };

  config = mkIf cfg.enable {
    boot.binfmt.emulatedSystems = cfg.emulatedSystems;
  };
}
