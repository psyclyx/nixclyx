{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    age
    just
    just-formatter
    nh
    nixfmt-rfc-style
    nixd
    nix-output-monitor
    nix-tree
    sops
    ssh-to-age
    yq
  ];
}
