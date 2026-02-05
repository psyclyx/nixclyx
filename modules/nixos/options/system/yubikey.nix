{
  path = ["psyclyx" "nixos" "system" "yubikey"];
  description = "yubikey support";
  config = {pkgs, ...}: {
    services.pcscd.enable = true;
    environment.systemPackages = [
      pkgs.yubikey-manager
      pkgs.yubico-piv-tool
      pkgs.opensc
      pkgs.ssh-agents
    ];
  };
}
