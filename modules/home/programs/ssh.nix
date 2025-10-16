{
  config,
  lib,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  cfg = config.psyclyx.programs.ssh;
in
{
  options = {
    psyclyx.programs.ssh = {
      enable = lib.mkEnableOption "SSH configuration";
    };
  };
  config = lib.mkIf cfg.enable {
    programs = {
      ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "*" = {
            addKeysToAgent = "yes";
            compression = true;
            extraOptions = {
              "UpdateHostKeys" = "no";
            };
            identityFile = "~/.ssh/id_psyclyx";
          }
          // lib.optionalAttrs isDarwin { "useKeychain" = "yes"; };

          "alice157.github.com" = {
            hostname = "github.com";
            identityFile = "~/.ssh/id_alice157";
          };

          "psyclyx.github.com" = {
            hostname = "github.com";
          };

          "psyclyx.net *.psyclyx.net psyclyx.xyz *.psyclyx.xyz" = {
            forwardAgent = true;
          };

          "router.home.psyclyx.net" = {
            user = "root";
          };
        };
      };
    };

    services = lib.mkIf pkgs.stdenv.isLinux {
      ssh-agent = {
        enable = true;
      };
    };
  };
}
