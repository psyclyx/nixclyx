{
  imports = [
    ./services/home-assistant.nix
    ./services/openssh.nix
    ./services/tailscale.nix
    ./system/console.nix
    ./system/locale.nix
    ./system/sudo.nix
  ];
}
