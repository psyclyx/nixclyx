{nixclyx}: {
  imports = nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;
}
