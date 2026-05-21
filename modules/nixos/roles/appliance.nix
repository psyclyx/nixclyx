# Appliance role — for recovery images and dedicated artifacts that
# aren't general-purpose servers. No users.psyc, no home-manager, no
# stylix/tailscale/fwupd/etc. Just the absolute minimum needed to
# boot, network, and SSH in.
{
  path = ["psyclyx" "nixos" "roles" "appliance"];
  variant = ["psyclyx" "nixos" "role"];
  description = "bare-bones appliance role (recovery, PXE artifacts)";
  config = {lib, ...}: {
    psyclyx.nixos = {
      network.networkd.enable = true;
      services.openssh.enable = true;

      # nixpkgs configuration is universal (channels, allowUnfree
      # decisions) — needed for the build to even resolve.
      system.nixpkgs.enable = true;
      system.nix.enable = lib.mkDefault true;
      system.locale.enable = lib.mkDefault true;
      system.timezone.enable = lib.mkDefault true;
    };
  };
}
