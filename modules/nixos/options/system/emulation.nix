{
  path = ["psyclyx" "nixos" "system" "emulation"];
  description = "Architecture emulation config";
  options = {
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) system;
    defaultSystems =
      {
        "x86_64-linux" = ["aarch64-linux"];
        "x86_64-darwin" = ["aarch64-darwin"];
        "aarch64-linux" = ["x86_64-linux"];
        "aarch64-darwin" = ["x86_64-darwin"];
      }
      .${
        system
      } or [
      ];
  in {
    emulatedSystems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Systems to emulate";
      example = ["aarch64-linux"];
      default = defaultSystems;
    };
  };
  config = {cfg, ...}: {
    boot.binfmt.emulatedSystems = cfg.emulatedSystems;
  };
}
