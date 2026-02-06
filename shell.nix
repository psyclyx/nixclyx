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
      pkgs.psyclyx.ensure-key
      pkgs.psyclyx.sign-key
      pkgs.psyclyx.pki
      nixfmt
      nixd
      nix-tree
      sops
      ssh-to-age
      yq
    ];
  }
