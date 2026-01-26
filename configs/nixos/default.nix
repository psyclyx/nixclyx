{ nixpkgs, ... }@deps:
let
  hosts = {
    sigil.modules = [ (import ./sigil deps) ];
    omen.modules = [ (import ./omen deps) ];
    tleilax.modules = [ (import ./tleilax deps) ];
    vigil.modules = [ (import ./vigil deps) ];
    lab-installer.modules = [ (import ./lab/installer.nix deps) ];
    lab-1.modules = [
      (import ./lab/base.nix deps)
      ./lab/lab-1.nix
    ];
    lab-2.modules = [
      (import ./lab/base.nix deps)
      ./lab/lab-2.nix
    ];
    lab-3.modules = [
      (import ./lab/base.nix deps)
      ./lab/lab-3.nix
    ];
    lab-4.modules = [
      (import ./lab/base.nix deps)
      ./lab/lab-4.nix
    ];
  };
in
builtins.mapAttrs (_: nixpkgs.lib.nixosSystem) hosts
