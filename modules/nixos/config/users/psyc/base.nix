{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.users.psyc.base;
in {
  options.psyclyx.nixos.config.users.psyc.base = {
    enable = lib.mkEnableOption "psyc base user";
  };

  config = lib.mkIf cfg.enable {
    users.users = {
      psyc = {
        extraGroups = [
          "wheel"
          "video"
        ];

        isNormalUser = true;
        openssh.authorizedKeys.keys = config.psyclyx.keys.psyc.openssh;
        shell = pkgs.zsh;
      };

      root.openssh.authorizedKeys.keys = config.psyclyx.keys.psyc.openssh;
    };
  };
}
