{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.self.homeManagerModules.default
    inputs.psyclyx-emacs.homeManagerModules.default
  ];
}
