{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.psyclyx.nixos.system.nix.enable {
    nix.settings.trusted-users = ["@wheel"];
  };
}
