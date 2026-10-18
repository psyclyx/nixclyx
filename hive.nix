# The Colmena hive: the shared `nodes` (what to build) with per-host
# `deployments` metadata layered on top (where/how to ship). Colmena reads
# this file with no arguments, so every input defaults to a standalone
# self-import; default.nix passes the injected values so the hive and the
# plain `configurations` are built from exactly the same nodes + pkgs.
{
  nixclyx ? import ./. { },
  nodes ? nixclyx.nodes,
  deployments ? nixclyx.deployments,
  # Colmena's meta.nixpkgs: the bare package set (see default.nix) — the
  # nodes bring their own overlays.
  hivePkgs ? nixclyx.hivePkgs,
}:
{
  meta.nixpkgs = hivePkgs;
}
// builtins.mapAttrs (name: deployment: {...}: {
  imports = [nodes.${name}];
  config.deployment = deployment;
}) deployments
