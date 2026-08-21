# The Colmena hive: the shared `nodes` (what to build) with per-host
# `deployments` metadata layered on top (where/how to ship). Colmena reads
# this file with no arguments, so every input defaults to a standalone
# self-import; default.nix passes the injected values so the hive and the
# plain `configurations` are built from exactly the same nodes + pkgs.
{
  nixclyx ? import ./. { },
  nodes ? nixclyx.nodes,
  deployments ? nixclyx.deployments,
  # The pkgs every host is built against — becomes Colmena's meta.nixpkgs.
  hostPkgs ? nixclyx.hostPkgs,
}:
{
  meta.nixpkgs = hostPkgs;
}
// builtins.mapAttrs (name: deployment: {...}: {
  imports = [nodes.${name}];
  config.deployment = deployment;
}) deployments
