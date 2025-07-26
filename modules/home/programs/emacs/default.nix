{
  config,
  pkgs,
  ...
}:
lib.mkIf (pkgs.stdenv.isDarwin && config.programs.emacs.enable) {
  targets.darwin.defaults."org.gnu.Emacs".AppleFontSmoothing = 0;
}
