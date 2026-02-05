{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "system" "nixpkgs"];
  description = "nixpkgs config";
  config = _: {
    psyclyx.common.system.nixpkgs.enable = true;
  };
} args
