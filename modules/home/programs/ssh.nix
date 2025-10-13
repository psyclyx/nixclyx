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
    psyclyx = {
      programs = {
        ssh = {
          enable = lib.mkEnableOption "Enable SSH config";
        };
      };
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

          "psyclyx.xyz *.psyclyx.xyz" = {
            forwardAgent = true;
          };

          "sigil.lan sigil sigil.local" = {
            forwardAgent = true;
          };

          "tleilax.lan tleilax tleilax.local tleilax.psyclyx.xyz" = {
            port = 17891;
            forwardAgent = true;
          };

          "*.lan" = {
            forwardAgent = true;
          };

          "openwrt.lan" = {
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
