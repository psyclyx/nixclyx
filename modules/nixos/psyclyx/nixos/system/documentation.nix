{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.system.documentation;
in
{
  options = {
    psyclyx.nixos.system.documentation = {
      enable = mkEnableOption "documentation generation";
    };
  };

  config = mkIf cfg.enable {
    documentation = {
      enable = true;
      dev.enable = true;
      doc.enable = true;
      info.enable = true;
      nixos = {
        enable = true;
        # Workaround: https://github.com/nix-community/stylix/issues/47
        # includeAllModules = true;
      };
    };
  };
}
