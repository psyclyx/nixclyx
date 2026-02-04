{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.users.psyc.workstation;
in {
  options.psyclyx.nixos.config.users.psyc.workstation = {
    enable = lib.mkEnableOption "psyc workstation user";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.config.users.psyc.base.enable = true;
    home-manager.users.psyc.psyclyx.home.config.workstation.enable = true;
  };
}
