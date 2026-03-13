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
              compression = false;
              extraOptions = {
                "UpdateHostKeys" = "no";
                "Ciphers" = "aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com";
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
