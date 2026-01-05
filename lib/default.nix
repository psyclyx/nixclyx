{
  lib ? <nixpkgs>.lib,
}:
{
  /*
    Converts a directory tree into a nested attrset mirroring its structure.

    Type: Path -> AttrSet

    - Directories become attrsets, keyed by name
    - Files become paths, keyed by name
    - Each directory attrset includes a "." attribute containing its own path

    Example:
      Given directory structure:
        /mydir/
          foo.txt
          bar/
            baz.txt

      dirToAttrSet /mydir
      # => {
      #   "." = /mydir;
      #   foo.txt = /mydir/foo.txt;
      #   bar = {
      #     "." = /mydir/bar;
      #     baz.txt = /mydir/bar/baz.txt;
      #   };
      # }
  */
  dirToAttrSet =
    dir:
    let
      recurse =
        dir:
        let
          entryValue =
            name: type:
            let
              name' = "${dir}/${name}";
              directory = type == "directory";
            in
            if directory then recurse name' else name';

          entries = lib.mapAttrs entryValue (builtins.readDir dir);
        in
        entries // { "." = dir; };
    in
    recurse dir;

  /*
    Calls `pkgs.callPackage` on each value in packageDefs, filtering out
    packages unsupported on the current platform.

    Type: Pkgs -> AttrSet (Path | Lambda) -> AttrSet Derivation

    A package is considered unsupported if `.meta.platforms` is:
      - Non-empty AND
      - Doesn't contain `pkgs.stdenv.hostPlatform.system`

    Packages with empty or missing `.meta.platforms` are always included.

    Note: This calls all packages first, then filters, so `.meta.platforms`
    must be cheap to compute.

    Example:
      callSupportedPackages pkgs {
        hello = ./hello.nix;  # meta.platforms = ["x86_64-linux"]
        foo = ./foo.nix;      # meta.platforms = ["aarch64-darwin"]
      }
      # On x86_64-linux => { hello = <derivation>; }
      # On aarch64-darwin => { foo = <derivation>; }
  */
  callSupportedPackages =
    pkgs: packageDefs:
    let
      callPackage' = f: pkgs.callPackage f { };
      supported =
        package:
        let
          system = pkgs.stdenv.hostPlatform.system;
          platforms = package.meta.platforms or [ ];
          empty = platforms == [ ];
          systemSupported = lib.elem system platforms;
        in
        empty || systemSupported;
    in
    lib.pipe packageDefs [
      (lib.mapAttrs (_: callPackage'))
      (lib.filterAttrs (_: supported))
    ];

  /*
    Creates flake outputs with both per-system and common (system-independent) attributes.

    Type: {
      systems :: [String]
      commonOutputs :: AttrSet
      perSystemArgs :: { system, ... } -> AttrSet
      perSystemOutputs :: AttrSet (ArgsAttrSet -> AttrSet)
    } -> AttrSet

    Arguments:
      systems          - List of system strings (e.g., ["x86_64-linux" "aarch64-darwin"])
      commonOutputs    - System-independent outputs (overlays, modules, etc.). Defaults to empty.
      perSystemArgs    - Transforms { system, ... } into args for perSystemOutputs functions.
                         Defaults to passing through system only.
      perSystemOutputs - AttrSet of functions producing system-specific outputs (packages, devShells).
                         Each function receives the result of perSystemArgs.

    Returns:
      Merged attrset with structure:
        - Common outputs at top level
        - Per-system outputs nested as: outputName.system.value

    Example:
      mkFlakeOutputs {
        systems = ["x86_64-linux" "aarch64-darwin"];
        commonOutputs = { overlays.default = final: prev: { }; };
        perSystemOutputs = {
          packages = { pkgs }: { hello = pkgs.hello; };
        };
      }
      # => {
      #   overlays.default = ...;
      #   packages.x86_64-linux.hello = <derivation>;
      #   packages.aarch64-darwin.hello = <derivation>;
      # }
  */
  mkFlakeOutputs =
    {
      systems,
      commonOutputs ? { },
      perSystemArgs ?
        { system, ... }:
        {
          inherit system;
        },
      perSystemOutputs ? { },
    }:
    let
      perSystemLeaf =
        f: system:
        lib.pipe { inherit system; } [
          perSystemArgs
          f
        ];
      perOutput = f: lib.genAttrs systems (perSystemLeaf f);
      perSystem = lib.mapAttrs (_: perOutput) perSystemOutputs;
    in
    commonOutputs // perSystem;
}
