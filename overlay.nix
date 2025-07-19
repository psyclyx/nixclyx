final: prev:
let
  inherit (prev.stdenv) isLinux;
  common = {
    emacs = prev.callPackage ./pkgs/emacs { };
  };
  linux = {
    rofi = prev.callPackage ./pkgs/rofi { };
    rofi-session = prev.callPackage ./pkgs/rofi-session.nix { };
  };
in
{
  psyclyx = common // (if isLinux then linux else { });
}
