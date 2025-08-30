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
        extraOptionOverrides = {
          "UpdateHostKeys" = "no";
        }
        // lib.optionalAttrs isDarwin { "useKeychain" = "yes"; };
        matchBlocks = {
          "*" = {
            compression = true;
            addKeysToAgent = "yes";
          };
          "alice157.github.com" = {
            identityFile = "~/.ssh/id_alice157";
            hostname = "github.com";
          };
          "codeberg.org" = {
            identityFile = "~/.ssh/id_psyclyx";
          };
          "gitlab.com" = {
            identityFile = "~/.ssh/id_psyclyx";
          };
          "psyclyx.github.com" = {
            identityFile = "~/.ssh/id_psyclyx";
            hostname = "github.com";
          };
          "psyclyx.xyz *.psyclyx.xyz" = {
            forwardAgent = true;
            identityFile = "~/.ssh/id_psyclyx";
          };
          "sigil.lan sigil sigil.local" = {
            forwardAgent = true;
            identityFile = "~/.ssh/id_psyclyx";
          };
          "tleilax.lan tleilax tleilax.local tleilax.psyclyx.xyz" = {
            port = 17891;
            forwardAgent = true;
            identityFile = "~/.ssh/id_psyclyx";
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
