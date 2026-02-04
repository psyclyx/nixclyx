let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;
  lib = import ./lib;
  assets = import ./assets;
  overlay = import ./overlay.nix;
  packages = import ./packages;

  modules = {
    nixos = {
      options = import ./modules/nixos/options;
      config = import ./modules/nixos/config;
    };
    darwin = {
      options = import ./modules/darwin/options;
      config = import ./modules/darwin/config;
    };
    home = {
      options = import ./modules/home/options;
      config = import ./modules/home/config;
    };
    common = {
      options = import ./modules/common/options;
      psyclyx = import ./modules/common/psyclyx;
    };
  };

  nixclyx = {
    inherit sources modules lib assets loadFlake;
    overlays.default = overlay;
  };

  evalConfig = import (sources.nixpkgs + "/nixos/lib/eval-config.nix");

  mkHost = name:
    evalConfig {
      system = "x86_64-linux";
      modules = [
        (modules.nixos.options {inherit nixclyx;})
        (modules.nixos.config {inherit nixclyx;})
        {config.psyclyx.nixos.config.hosts.${name}.enable = true;}
      ];
    };

  configurations = builtins.mapAttrs (name: _: mkHost name) {
    sigil = {};
    omen = {};
    vigil = {};
    tleilax = {};
    lab-1 = {};
    lab-2 = {};
    lab-3 = {};
    lab-4 = {};
  };

  darwinSystem = (loadFlake sources.nix-darwin).lib.darwinSystem;

  mkDarwinHost = name:
    darwinSystem {
      modules = [
        (modules.darwin.options {inherit nixclyx;})
        (modules.darwin.config {inherit nixclyx;})
        {config.psyclyx.darwin.config.hosts.${name}.enable = true;}
      ];
    };

  darwinConfigurations = builtins.mapAttrs (name: _: mkDarwinHost name) {
    halo = {};
  };
in
  nixclyx // {inherit configurations darwinConfigurations;}
