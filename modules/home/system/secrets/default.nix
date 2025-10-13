{
  config,
  lib,
  pkgs,
  ...
}:
let
  configHome = config.xdg.configHome;
  home = config.home.homeDirectory;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  cfg = config.psyclyx.secrets;
in
{
  options = {
    psyclyx.secrets = {
      enable = lib.mkEnableOption "Runtime secret decryption with sops-nix";
    };
  };
  config = lib.mkIf cfg.enable {
    sops = {
      age.keyFile =
        if isDarwin then
          "${home}/Library/Application Support/sops/age/keys.txt"
        else
          "${configHome}/sops/age/keys.txt";
      secrets = {
        ".ssh/id_psyclyx" = {
          sopsFile = ./ssh/psyclyx.json;
          key = "private_key";
          path = "${home}/.ssh/id_psyclyx";
        };
        ".ssh/id_alice157" = {
          sopsFile = ./ssh/alice157.json;
          key = "private_key";
          path = "${home}/.ssh/id_alice157";
        };
        github = {
          sopsFile = ./tokens.json;
          key = "github";
          path = ".tokens/github";
        };
        openrouter = {
          sopsFile = ./tokens.json;
          key = "openrouter";
          path = ".tokens/openrouter";
        };
        replicate = {
          sopsFile = ./tokens.json;
          key = "replicate";
          path = ".tokens/replicate";
        };
      };
    };
  };
}
