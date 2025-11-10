{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.roles.dev;
in
{
  options = {
    psyclyx.roles.dev = {
      enable = mkEnableOption "languages, tools, runtimes, etc";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.babashka
      pkgs.cljstyle
      pkgs.clojure
      pkgs.jet
      pkgs.leiningen
      pkgs.temurin-bin-25

      pkgs.nixd

      pkgs.clang
      pkgs.gcc
      pkgs.lldb
      pkgs.meson
      pkgs.ninja
      pkgs.rr
      pkgs.valgrind

      pkgs.zig_0_15
      pkgs.zls_0_15

      pkgs.python3

      pkgs.jq
      pkgs.nodejs
    ];
  };
}
