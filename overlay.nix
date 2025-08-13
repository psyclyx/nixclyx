{ psyclyx-emacs, ... }:
final: prev:
let
  inherit (prev.stdenv) isLinux;
  common = {
    upscale-image = prev.callPackage ./pkgs/upscale-image.nix { };
    print256colors = prev.callPackage ./pkgs/print256colors.nix { };
  };
  linux = {
    rofi = prev.callPackage ./pkgs/rofi { };
    rofi-session = prev.callPackage ./pkgs/rofi-session.nix { };
  };
in
{
  psyclyx = common // (if isLinux then linux else { });
}
