pkgs:
let
  inherit (pkgs) callPackage stdenv;
  inherit (stdenv) isDarwin isLinux;
in
if isLinux then { rofi = callPackage ./rofi; } else { }
