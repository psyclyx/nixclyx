{nixclyx}: {
  imports = nixclyx.lib.fs.collectSpecs nixclyx.lib.spec.mkModule ./.;
}
