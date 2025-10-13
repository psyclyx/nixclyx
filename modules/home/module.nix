{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.psyclyx-emacs.homeManagerModules.default
    ./config.nix
    ./programs
    ./roles
    ./services
    ./system
  ];
}
