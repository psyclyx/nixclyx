{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.users.psyc;
in
{
  options = {
    psyclyx.nixos.users.psyc = {
      enable = lib.mkEnableOption "psyc user";
      server = lib.mkEnableOption "roles for server";
      hmImport = lib.mkOption {
        default = { };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = {
      psyc = {
        extraGroups = [
          "wheel"
          "video"
        ];

        isNormalUser = true;
        openssh.authorizedKeys.keys = inputs.self.common.keys.psyc.openssh;
        shell = pkgs.zsh;
      };

      root.openssh.authorizedKeys.keys = inputs.self.common.keys.psyc.openssh;
    };

    home-manager.users.psyc = {
      imports = [
        inputs.self.homeManagerModules.psyclyx
        cfg.hmImport
      ];

      config = {
        psyclyx = {
          home = {
            info = {
              name = "psyclyx";
              email = "me@psyclyx.xyz";
            };

            roles = {
              shell.enable = true;
              dev.enable = lib.mkIf (!cfg.server) true;
              graphical.enable = lib.mkIf (!cfg.server) true;
            };

            secrets.enable = lib.mkIf (!cfg.server) true;
            xdg.enable = true;
          };
        };
      };
    };
  };
}
