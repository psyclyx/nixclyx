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
      nixfmt-rfc-style
      nixd
      nix-tree
      sops
      ssh-to-age
      yq
    ];
  };
}
