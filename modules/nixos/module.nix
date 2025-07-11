{
  imports = [
    ./services/automount.nix
    ./services/gnome-keyring.nix
    ./services/greetd.nix
    ./services/home-assistant.nix
    ./services/openssh.nix
    ./services/tailscale.nix
    ./system/console.nix
    ./system/locale.nix
    ./system/nix.nix
    ./system/sudo.nix
    ./system/virtualization.nix
  ];
}
