{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.psyclyx-emacs.homeManagerModules.default
    ./config.nix
    ./programs/alacritty.nix
    ./programs/emacs.nix
    ./programs/git.nix
    ./programs/kitty.nix
    ./programs/ssh.nix
    ./programs/sway
    ./programs/waybar.nix
    ./programs/zsh.nix
    ./roles/dev.nix
    ./roles/graphical.nix
    ./roles/shell.nix
    ./secrets
    ./xdg.nix
  ];
}
