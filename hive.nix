{nixclyx ? import ./.}: let
  pkgs = import ./nixpkgs.nix {};
  lib = pkgs.lib;

  # Load egregore so deployment targets can derive from each host's
  # declared deployAddress / deployUser / sshPort. Mirror the loader
  # pattern from ./default.nix's fleet-viz section.
  spec = import ./egregore.nix;
  egregorePkg = import spec.lib { inherit lib; };
  eg = egregorePkg.eval { modules = [spec.root]; };

  fromEgregore = name: let
    h = (eg.entities.${name} or { host = { }; }).host or { };
    target = h.deployAddress or null;
  in
    lib.optionalAttrs (target != null) {
      targetHost = target;
      targetUser = h.deployUser or "root";
    }
    // lib.optionalAttrs ((h.sshPort or 22) != 22) {
      targetPort = h.sshPort;
    };

  mkHost = name: extras: { ... }: {
    imports = [
      nixclyx.modules.nixos
      nixclyx.hosts.nixos.${name}
    ];
    config.deployment = (fromEgregore name) // extras;
  };
in {
  meta = {
    nixpkgs = pkgs;
  };

  sigil = mkHost "sigil" {
    tags = [
      "apartment"
      "workstation"
      "desktop"
      "fixed"
    ];
    allowLocalDeployment = true;
  };

  # Not in egregore yet — manual target stays.
  omen = mkHost "omen" {
    tags = [
      "workstation"
      "laptop"
    ];
    allowLocalDeployment = true;
  };

  # Not in egregore yet — manual target.
  glyph = { ... }: {
    imports = [
      nixclyx.modules.nixos
      nixclyx.hosts.nixos.glyph
    ];
    config.deployment = {
      tags = [
        "workstation"
        "laptop"
      ];
      allowLocalDeployment = true;
      targetHost = "10.1.0.240";
      targetUser = "root";
    };
  };

  iyr = mkHost "iyr" {
    tags = [
      "apartment"
      "router"
      "minipc"
      "fixed"
    ];
  };

  tleilax = mkHost "tleilax" {
    tags = [
      "server"
      "colo"
      "fixed"
    ];
  };

  semuta = mkHost "semuta" {
    tags = [
      "server"
      "vps"
      "fixed"
    ];
  };

  lab-1 = mkHost "lab-1" {
    tags = [
      "server"
      "apartment"
      "lab"
      "fixed"
    ];
  };

  lab-2 = mkHost "lab-2" {
    tags = [
      "server"
      "apartment"
      "lab"
      "fixed"
    ];
  };

  lab-3 = mkHost "lab-3" {
    tags = [
      "server"
      "apartment"
      "lab"
      "fixed"
    ];
  };

  lab-4 = mkHost "lab-4" {
    tags = [
      "server"
      "apartment"
      "lab"
      "fixed"
    ];
  };
}
