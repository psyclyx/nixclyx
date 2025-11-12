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
            identityFile = config.sops.secrets."ssh/id_psyclyx".path or null;
          }
          // lib.optionalAttrs isDarwin { "useKeychain" = "yes"; };

          "alice157.github.com" = {
            hostname = "github.com";
            identityFile = config.sops.secrets."ssh/id_alice157".path or null;
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

          "tleilax" = {
            hostname = "tleilax.psyclyx.xyz";
            port = 17891;
            forwardAgent = true;
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
