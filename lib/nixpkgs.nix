{ ... }:
rec {
  # Options used to initialize pkgs from the nixpkgs input
  pkgsOptions = {
    config.allowUnfree = true;
    nvidia.acceptLicense = true;
  };

  # Initialize `pkgs` from `nixpkgs` for `system`
  systemPkgs =
    nixpkgs: system:
    import nixpkgs {
      inherit system;
    }
    // pkgsOptions;

  # Call `f` with `nixpkgs` initialized for `system`
  withSystemPkgs =
    nixpkgs: system: f:
    f (systemPkgs nixpkgs system);
}
