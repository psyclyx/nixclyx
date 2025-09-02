{ inputs, pkgs, ... }:
{
  system.stateVersion = "25.05";
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.stylix.nixosModules.stylix
    ../../../modules/nixos/module.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];

  psyclyx = {
    programs = {
      aspell.enable = true;
      sway.enable = true;
    };
    services = {
      autoMount.enable = true;
      gnome-keyring.enable = true;
      greetd.enable = true;
      locate = {
        enable = true;
        users = [ "psyc" ];
      };
      openssh.enable = true;
      kanata.enable = true;
      printing.enable = true;
      tailscale.enable = true;
    };
    system = {
      fonts.enable = true;
      sudo.enable = true;
    };
  };
}
