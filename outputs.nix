{ nixpkgs, ... }@inputs:
let
  inherit (nixpkgs) lib;

  mkPkgs =
    system:
    import nixpkgs {
      hostPlatform = system;
      config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };
    };

  mkFlakeOutputs =
    {
      systems,
      commonOutputs ? { },
      perSystemOutputs ? { },
    }:
    let
      outputs =
        commonOutputs
        // (lib.mapAttrs (
          output: f:
          lib.genAttrs systems (
            system:
            f {
              inherit system outputs;
              pkgs = mkPkgs system;
            }
          )
        ) perSystemOutputs);
    in
    outputs;

in
mkFlakeOutputs {
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  commonOutputs = {
    assets = import ./assets;
    passthrough = inputs;
  }
  // import ./configs { inherit inputs; };

  perSystemOutputs = {
    packages = { pkgs, ... }: import ./packages { inherit pkgs; };
    devShells = { pkgs, ... }: import ./shell.nix { inherit pkgs; };
  };
}
