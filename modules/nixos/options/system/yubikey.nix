{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "yubikey"];
  description = "yubikey support";
  config = _: {
    services.pcscd.enable = true;
    environment.systemPackages = [
      pkgs.yubikey-manager
      pkgs.yubico-piv-tool
      pkgs.opensc
      pkgs.ssh-agents
    ];
  };
} args
