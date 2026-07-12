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
        settings."*" =
          {
            AddKeysToAgent = "yes";
            Compression = false;
            UpdateHostKeys = "no";
            Ciphers = "aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com";
          }
          // lib.optionalAttrs isDarwin {UseKeychain = "yes";};
      };
    };

    services = lib.mkIf isLinux {
      ssh-agent = {
        enable = true;
      };
    };
  };
}
