{
  pkgs,
  colmena,
  system,
  ...
}:
{
  default = pkgs.mkShell {
    packages = with pkgs; [
      colmena.packages."${system}".colmena
      nixfmt
      nixd
      nix-tree
      sops
      ssh-to-age
      yq
    ];
  };
}
