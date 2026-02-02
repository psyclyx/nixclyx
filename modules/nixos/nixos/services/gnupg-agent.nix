{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.services.gnupg-agent;
in {
  options = {
    psyclyx.nixos.services.gnupg-agent = {
      enable = lib.mkEnableOption "gnupg agent (for pinentry)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gnupg.agent = {
      enable = true;
    };
  };
}
