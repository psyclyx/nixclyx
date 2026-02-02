let
  attrs = import ./attrs.nix;

  withOptionSpecs = optionSpecs: moduleSpec:
    moduleSpec // {optionSpecs = moduleSpec.options ++ optionSpecs;};

  mkOptionFnFromSpec = optionSpec @ {
    path,
    mkOption',
    ...
  }: moduleArgs @ {lib, ...}: {
    inherit path;
    value = mkOption' {inherit moduleArgs optionSpec;};
  };

  mkModule = {
    imports ? [],
    optionSpecs ? [],
    configSpecs ? [],
  }: {
    lib,
    cfg,
    ...
  }: {
  };
in {
  inherit mkModule;
}
