# The deployment-free definition of each NixOS host: *what to build*, with
# no notion of where or how it's deployed. This is the single source both
# consumers derive from — `default.nix` evaluates these into plain
# `configurations` (for `nixos-rebuild -A`), and `hive.nix` layers Colmena
# deployment metadata on top of the same nodes.
#
# Each value is an ordinary NixOS module fragment (`{ imports = …; }`).
{ nixclyx }:
builtins.mapAttrs (_name: hostPath: {
  imports = [
    nixclyx.modules.nixos
    hostPath
  ];
}) nixclyx.hosts.nixos
