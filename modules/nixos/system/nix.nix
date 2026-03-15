{
  path = ["psyclyx" "nixos" "system" "nix"];
  description = "nix config";
  options = {lib, ...}: {
    githubAccessTokensFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a nix.conf snippet file containing access-tokens.
        The file should contain a line like: access-tokens = github.com=ghp_xxx
        Use sops.templates to generate this from a secret token.
      '';
    };
  };
  config = {
    cfg,
    lib,
    ...
  }: {
    psyclyx.common.system.nix.enable = true;
    nix.settings.trusted-users = ["@wheel"];

    # !include reads the file at nix daemon startup, not build time
    # If the file doesn't exist, nix continues without error
    nix.extraOptions = lib.mkIf (cfg.githubAccessTokensFile != null) ''
      !include ${cfg.githubAccessTokensFile}
    '';
  };
}
