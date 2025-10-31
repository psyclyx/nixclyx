{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.psyclyx-emacs.homeManagerModules.default
    ./programs
    ./roles
    ./services
    ./system
    ./user.nix
  ];
}
