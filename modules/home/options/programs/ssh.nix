{
  path = ["psyclyx" "home" "programs" "ssh"];
  description = "SSH configuration";
  config = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  in {
    programs = {
      ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "*" =
            {
              addKeysToAgent = "yes";
              compression = true;
              extraOptions = {
                "UpdateHostKeys" = "no";
              };
              identityFile = config.sops.secrets."ssh/id_psyclyx".path or null;
            }
            // lib.optionalAttrs isDarwin {"useKeychain" = "yes";};

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
            # hostname = "tleilax.psyclyx.xyz";
            port = 17891;
            forwardAgent = true;
          };
        };
      };
    };

    services = lib.mkIf isLinux {
      ssh-agent = {
        enable = true;
      };
    };
  };
}
