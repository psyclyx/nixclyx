{
  imports = [
    ./services/home-assistant.nix
    ./services/openssh.nix
    ./services/tailscale.nix
    ./services/automount.nix
    ./system/console.nix
    ./system/locale.nix
    ./system/sudo.nix
  ];
}
