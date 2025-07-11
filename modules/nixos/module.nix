{
  imports = [
    ./programs/adb.nix
    ./services/automount.nix
    ./services/gnome-keyring.nix
    ./services/greetd.nix
    ./services/home-assistant.nix
    ./services/openssh.nix
    ./services/printing.nix
    ./services/tailscale.nix
    ./system/console.nix
    ./system/locale.nix
    ./system/nix.nix
    ./system/sudo.nix
    ./system/virtualization.nix
  ];
}
