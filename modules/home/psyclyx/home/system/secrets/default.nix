{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  configHome = config.xdg.configHome;
  home = config.home.homeDirectory;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  cfg = config.psyclyx.home.secrets;
in
{
  options = {
    psyclyx.home.secrets = {
      enable = mkEnableOption "Runtime secret decryption with sops-nix";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.bitwarden-cli ];

    sops = {
      age.keyFile =
        if isDarwin then
          "${home}/Library/Application Support/sops/age/keys.txt"
        else
          "${configHome}/sops/age/keys.txt";

      defaultSopsFile = ./secrets.json;
      secrets = {
        "ssh/id_psyclyx".path = "${configHome}/.ssh/id_psyclyx";
        "ssh/id_alice157".path = "${configHome}/.ssh/id_alice157";
        github = { };
        openrouter.path = ".tokens/openrouter";
        replicate.path = ".tokens/replicate";
      };
    };
  };
}
