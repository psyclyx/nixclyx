final: prev: {
  psyclyx = {
    rofi = prev.callPackage ./pkgs/rofi {};
    rofi-session = prev.callPackage ./pkgs/rofi-session.nix {};
    emacs = prev.callPackage ./pkgs/emacs {};
  };
}
