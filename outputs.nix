inputs:
let
  inherit (inputs) nixpkgs colmena self;
  inherit (nixpkgs) lib;
  nixclyx = self;

  psyclib = import ./lib { inherit lib; };
in
psyclib.mkFlakeOutputs {
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  perSystemArgs =
    { system, ... }:
    {
      inherit
        colmena
        nixclyx
        system
        ;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
        };
        overlays = [ nixclyx.overlays.default ];
      };
    };

  perSystemOutputs = {
    packages = import ./packages;
    devShells = import ./devShells;
    envs = import ./envs;
  };

  commonOutputs = {
    assets = import ./assets { inherit nixclyx; };
    colmenaHive = import ./colmenaHive.nix {
      inherit
        colmena
        nixclyx
        nixpkgs
        inputs
        ;
    };
    lib = psyclib;
    overlays = import ./overlays { inherit nixclyx; };
    passthrough = inputs;
  }
  // (import ./configs { inherit inputs; })
  // (import ./modules { inherit lib; });
}
