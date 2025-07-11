{ ... }:
{
  imports = [
    ../../modules/platform/darwin/base
    ../../modules/platform/darwin/desktop
    ../../modules/platform/darwin/programs/zsh.nix
    ../../modules/platform/darwin/services/tailscale.nix
    ./users.nix
    ./casks.nix
  ];
}
