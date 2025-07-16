{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.clojure;
in
{
  options = {
    psyclyx = {
      tools = {
        clojure = {
          enable = lib.mkEnableOption "Clojure tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        babashka
        clj-kondo
        cljstyle
        clojure
        clojure-lsp
        leiningen
        maven
      ];
    };
  };
}
