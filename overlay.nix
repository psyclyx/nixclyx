{ psyclyx-emacs, ... }:
final: prev:
let
  inherit (prev.stdenv) isLinux;
  common = {
    upscale-image = prev.callPackage ./packages/upscale-image.nix { };
    print256colors = prev.callPackage ./packages/print256colors.nix { };
  };
  linux = { };
in
{
  psyclyx = common // (if isLinux then linux else { });
}
