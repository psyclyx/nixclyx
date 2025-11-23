{ nixpkgs, ... }@inputs:
let
  inherit (nixpkgs.lib) genAttrs mapAttrs;

  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
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
        // (mapAttrs (
          output: f:
          genAttrs systems (
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
  // (import ./configs { inherit inputs; })
  // (import ./modules);

  perSystemOutputs = {
    packages = { pkgs, ... }: import ./packages { inherit pkgs; };
    devShells =
      { pkgs, ... }:
      {
        default = import ./shell.nix { inherit pkgs; };
      };
  };
}
