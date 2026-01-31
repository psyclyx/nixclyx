{ nixpkgs, nixclyx, ... }@deps:
let
  module = nixclyx.nixosModules.default;

  hosts = {
    sigil.modules = [
      module
      ./sigil
    ];
    omen.modules = [
      module
      ./omen
    ];
    tleilax.modules = [
      module
      ./tleilax
    ];
    vigil.modules = [
      module
      ./vigil
    ];

    lab-1.modules = [
      module
      ./lab/lab-1.nix
    ];
    lab-2.modules = [
      module
      ./lab/lab-2.nix
    ];
    lab-3.modules = [
      module
      ./lab/lab-3.nix
    ];
    lab-4.modules = [
      module
      ./lab/lab-4.nix
    ];
  };
in
builtins.mapAttrs (_: nixpkgs.lib.nixosSystem) hosts
