# HA Group Service auto-enablement projection.
#
# Reads the host's membership in HA groups from the egregore data and
# automatically enables the corresponding NixOS service modules, injecting
# the cluster nodes and network.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;

  # Find all HA groups this host is a member of
  myGroups = lib.filterAttrs (
    _: g: g.type == "ha-group" && builtins.elem hostname g.ha-group.members
  ) eg.entities;

  # Helper to check if a service exists in any of our groups
  hasService = svc: builtins.any (g: g.ha-group.services ? ${svc}) (builtins.attrValues myGroups);

  # Helper to get the group entity that provides a specific service
  getGroupFor =
    svc:
    builtins.head (builtins.filter (g: g.ha-group.services ? ${svc}) (builtins.attrValues myGroups));

  # Collect unique cluster members and the primary network for a service
  clusterNodesFor = svc: (getGroupFor svc).ha-group.members;
  networkFor = svc: (getGroupFor svc).ha-group.network;

in
{
  config = lib.mkIf (myGroups != { }) {
    psyclyx.nixos.services = {
      patroni = lib.mkIf (hasService "postgresql") {
        enable = true;
        dataNetwork = networkFor "postgresql";
        clusterNodes = clusterNodesFor "postgresql";
      };

      redis-sentinel = lib.mkIf (hasService "redis") {
        enable = true;
        dataNetwork = networkFor "redis";
        clusterNodes = clusterNodesFor "redis";
      };

      openbao = lib.mkIf (hasService "openbao") {
        enable = true;
        clusterNodes = clusterNodesFor "openbao";
      };

      seaweedfs = lib.mkIf (hasService "s3" || hasService "webdav") {
        enable = true;
        dataNetwork = networkFor "s3"; # Or webdav, they should be in the same group
        clusterNodes = clusterNodesFor "s3";
        masterNodes = lib.take 3 (clusterNodesFor "s3");
        s3.enable = hasService "s3";
        webdav.enable = hasService "webdav";
        # Buckets are still created by lab-shared since that's a site-specific
        # configuration detail, but the daemon structure is identical across
        # environments.
      };
    };
  };
}
