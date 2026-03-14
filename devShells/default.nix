{
  pkgs,
  colmena,
  system,
  ...
}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      colmena.packages."${system}".colmena
      pkgs.psyclyx.provision-host
      pkgs.psyclyx.pki-manage
      pkgs.psyclyx.switch-deploy
      nixfmt
      nixd
      nix-tree
      sops
      ssh-to-age
      yq
    ];
  };
}
