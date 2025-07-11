pkgs:
pkgs.mkShell {
  packages = with pkgs; [
    age
    nixfmt-rfc-style
    nixd
    sops
    ssh-to-age
  ];
}
