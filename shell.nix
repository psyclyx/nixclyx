{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    age
    just
    just-formatter
    nixfmt-rfc-style
    nixd
    sops
    ssh-to-age
    yq
  ];
}
