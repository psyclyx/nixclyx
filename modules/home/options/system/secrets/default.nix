{
  path = ["psyclyx" "home" "secrets"];
  description = "Runtime secret decryption with sops-nix";
  config = {config, lib, pkgs, ...}: let
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

    sops = {
      age.keyFile =
        if isDarwin
        then "${home}/Library/Application Support/sops/age/keys.txt"
        else "${configHome}/sops/age/keys.txt";

      defaultSopsFile = ./secrets.json;

      secrets = {
        "ssh/id_psyclyx".path = "${configHome}/.ssh/id_psyclyx";
        "ssh/id_alice157".path = "${configHome}/.ssh/id_alice157";
        github = {};
        openrouter.path = ".tokens/openrouter";
        replicate.path = ".tokens/replicate";
      };
    };
  };
}
