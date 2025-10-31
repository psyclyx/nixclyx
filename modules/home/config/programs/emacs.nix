{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.programs.emacs;
in
{
  options = {
    psyclyx.programs.emacs = {
      enable = lib.mkEnableOption "Emacs text editor";
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.emacs = {
          enable = true;
          defaultEditor = true;
        };
        psyclyx-emacs.enable = true;
      }
      (lib.mkIf (pkgs.stdenv.isDarwin && config.programs.emacs.enable) {
        targets.darwin.defaults."org.gnu.Emacs".AppleFontSmoothing = 0;
      })
    ]
  );
}
