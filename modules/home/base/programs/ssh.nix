{
  lib,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs = {
    ssh = {
      enable = true;
      compression = true;
      addKeysToAgent = "yes";
      extraOptionOverrides = {
        "UpdateHostKeys" = "no";
      } // lib.optionalAttrs isDarwin { "useKeychain" = "yes"; };
      matchBlocks = {
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
}
