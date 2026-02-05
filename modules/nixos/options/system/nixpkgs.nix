{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "nixpkgs"];
  description = "nixpkgs config";
  config = _: {
    psyclyx.common.system.nixpkgs.enable = true;
  };
} args
