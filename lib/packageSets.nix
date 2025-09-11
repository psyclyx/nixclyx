{
  psyclyxLib,
  ...
}:
let
  inherit (psyclyxLib) systems;
in
{
  # Returns an attrset with the result of `pkgs.callPackage def.path` for every `packageDef` where
  # `pkgs.system` appears in `packageDef.systems`.
  # A `packageDef` is an attrset with
  #   - `path`: path to a nix file containing a derivation
  #   - `systems` (optional): values of `pkgs.system` this packageDef applies to.
  #     Defaults to `psyclyxLib.systems.all`
  mkPackageSet =
    pkgs: packageDefs:
    let
      # Use supplied `pkgs` for everything. I don't think it really
      # matters, but it's probably more robust to future nixpkgs
      # changes?
      inherit (pkgs) callPackage lib system;
      defSupported = _: def: lib.elem system (def.systems or systems.all);
      supportedDefs = lib.filterAttrs defSupported packageDefs;
      callDef = _: def: callPackage def.path { };
    in
    lib.mapAttrs callDef packageDefs;
}
