# VM role — minimal NixOS for service microvms. Strictly the pieces
# needed to boot, network, sync time, and accept SSH. No home-manager,
# stylix, fonts, tailscale, fwupd, yubikey, containers, docs, or
# storage/bcachefs sugar — all of which inflate the closure for
# headless service VMs that have none of those concerns.
{
  path = ["psyclyx" "nixos" "roles" "vm"];
  variant = ["psyclyx" "nixos" "role"];
  description = "minimal role for service microvms";
  config = {lib, ...}: {
    psyclyx.nixos = {
      network.networkd.enable = true;
      network.firewall.enable = lib.mkDefault true;

      services.openssh.enable = true;
      services.chrony.enable = lib.mkDefault true;

      system.nixpkgs.enable = true;
      system.nix.enable = lib.mkDefault true;
      system.locale.enable = lib.mkDefault true;
      system.timezone.enable = lib.mkDefault true;
    };
  };
}
