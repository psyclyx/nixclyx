{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.system.yubikey;
in
{
  options = {
    psyclyx.nixos.system.yubikey = {
      enable = lib.mkEnableOption "yubikey support";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pcscd.enable = true;
    environment.systemPackages = [
      pkgs.yubikey-manager
      pkgs.yubico-piv-tool
      pkgs.opensc
      pkgs.ssh-agents
    ];
  };
}
