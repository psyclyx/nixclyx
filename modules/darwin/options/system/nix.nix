{
  path = ["psyclyx" "darwin" "system" "nix"];
  description = "nix config";
  config = _: {
    psyclyx.common.system.nix.enable = true;
    nix.settings.trusted-users = ["@admin"];
  };
}
