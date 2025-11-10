{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    optionals
    types
    ;

  cfg = config.psyclyx.users.psyc;
in
{
  options = {
    psyclyx.users.psyc = {
      enable = mkEnableOption "psyc user";
      server = mkEnableOption "roles for server";
      hmImport = mkOption {
        default = { };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = {
      psyc = {
        name = "psyc";
        shell = pkgs.zsh;
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
        ];
        openssh.authorizedKeys.keys = inputs.self.common.keys.psyc.openssh;
      };
      root.openssh.authorizedKeys.keys = inputs.self.common.keys.psyc.openssh;
    };

    home-manager.users.psyc = {
      imports = [
        inputs.self.homeManagerModules.config
        cfg.hmImport
      ];

      config = {
        psyclyx = {
          user = {
            name = "psyclyx";
            email = "me@psyclyx.xyz";
          };

          roles = {
            shell.enable = true;
            dev.enable = lib.mkIf (!cfg.server) true;
            graphical.enable = lib.mkIf (!cfg.server) true;
          };
          secrets.enable = lib.mkIf (!cfg.server) true;
        };
      };
    };
  };
}
