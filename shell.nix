let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {
    overlays = [(import ./overlay.nix)];
    config = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
  };
in
  pkgs.mkShell {
    packages = with pkgs; [
      pkgs.colmena.colmena
      nixfmt
      nixd
      nix-tree
      pkgs.psyclyx.regenerate-palettes
      pkgs.psyclyx.egregore
      sops
      ssh-to-age
      yq
    ];
  }
