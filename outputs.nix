inputs:
let
  inherit (inputs) nixpkgs self;
  psycLib = import ./lib { inherit (nixpkgs) lib; };
  inherit (psycLib) mkFlakeOutputs;
in
mkFlakeOutputs {
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  perSystemArgs =
    { system, ... }@args:
    args
    // {
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
        };
      };
    };

  perSystemOutputs = {
    packages = import ./packages;
    devShells = import ./devShells;
    envs = import ./envs;
    checks =
      { outputs, system, ... }:
      let
      in
      {
      };
  };

  commonOutputs =
    outputs:
    {
      assets = import ./assets { psycNix = outputs; };
      lib = import ./lib { inherit (nixpkgs) lib; };
      passthrough = inputs;
    }
    // (import ./configs { inherit inputs; })
    // (import ./modules);
}
