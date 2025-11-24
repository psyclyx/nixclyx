{ pkgs, ... }:
{
  default = pkgs.mkShell {
    packages = with pkgs; [
      age
      nixfmt-rfc-style
      nixd
      nix-tree
      sops
      ssh-to-age
      yq
    ];
  };
}
