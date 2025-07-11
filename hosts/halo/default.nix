{ ... }:
{
  imports = [
    ../../modules/darwin/base
    ../../modules/darwin/desktop
    ../../modules/darwin/programs/zsh.nix
    ../../modules/darwin/services/tailscale.nix
    ./users.nix
    ./casks.nix
  ];
}
