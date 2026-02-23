{
  path = ["psyclyx" "home" "secrets"];
  description = "Runtime secret decryption with sops-nix";
  options = {lib, ...}: {
    defaultSopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Default sops file for home secrets";
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    configHome = config.xdg.configHome;
    home = config.home.homeDirectory;
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  in {
    home.packages =
      [
        pkgs.bitwarden-cli
        pkgs.rbw
      ]
      ++ lib.optionals config.psyclyx.home.programs.fuzzel.enable [pkgs.rofi-rbw];

    sops.age.keyFile =
      if isDarwin
      then "${home}/Library/Application Support/sops/age/keys.txt"
      else "${configHome}/sops/age/keys.txt";

    sops.defaultSopsFile = lib.mkIf (cfg.defaultSopsFile != null) cfg.defaultSopsFile;
  };
}
