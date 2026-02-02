{nixpkgs, ...} @ deps: {
  config = nixpkgs.lib.importApply ./config deps;
}
