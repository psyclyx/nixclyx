{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
lib.mkMerge [
  {
    programs = {
      emacs = {
        enable = lib.mkDefault false;
        package = lib.mkDefault pkgs.psyclyx.emacs;
      };
    };

    home = with inputs.psyclyx-emacs.files; lib.mkIf config.programs.emacs.enable {
      file.".config/emacs" = {
        source = pkgs.psyclyx.emacsConfig;
        recursive = true;
      };
    };
  }

  (lib.mkIf (pkgs.stdenv.isDarwin && config.programs.emacs.enable) {
    targets.darwin.defaults."org.gnu.Emacs".AppleFontSmoothing = 0;
  })
]
