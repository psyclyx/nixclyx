{ psyclyx-emacs, ... }:
final: prev:
let
  inherit (prev.stdenv) isLinux;
  linux = {
    rofi = prev.callPackage ./pkgs/rofi { };
    rofi-session = prev.callPackage ./pkgs/rofi-session.nix { };
  };
in
{
  psyclyx = if isLinux then linux else { };
}
