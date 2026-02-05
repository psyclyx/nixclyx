{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "nix"];
  description = "nix config";
  config = _: {
    psyclyx.common.system.nix.enable = true;
    nix.settings.trusted-users = ["@wheel"];
  };
} args
