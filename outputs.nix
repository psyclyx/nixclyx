inputs:
let
  inherit (inputs) nixpkgs colmena;

  psyclib = import ./lib { inherit (nixpkgs) lib; };

  deps = inputs // {
    inherit nixclyx;
  };

  nixclyx = psyclib.mkFlakeOutputs {
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
      assets = import ./assets deps;
      colmenaHive = import ./colmenaHive.nix deps;
      lib = psyclib;
      overlays = import ./overlays deps;
      passthrough = nixclyx;
    }
    // (import ./configs deps)
    // (import ./modules deps);
  };
in
nixclyx
