{
  pkgs,
  colmena,
  system,
  ...
}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      colmena.packages."${system}".colmena
      pkgs.psyclyx.ensure-key
      pkgs.psyclyx.sign-key
      pkgs.psyclyx.provision-host
      nixfmt
      nixd
      nix-tree
      sops
      ssh-to-age
      yq
    ];
  };
}
