# HA-group → cluster projection inputs.
#
# For each ha-group this host is a member of, populates the matching
# derived/* projection's `dataNetwork` + `clusterNodes` (and the
# generic seaweedfs module's s3/webdav enables). Each derived/*
# projection then activates implicitly because its `clusterNodes` is
# non-empty.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;

  myGroups = lib.filterAttrs (
    _: g: g.type == "ha-group" && builtins.elem hostname g.ha-group.members
  ) eg.entities;

  hasService = svc: builtins.any (g: g.ha-group.services ? ${svc}) (builtins.attrValues myGroups);

  groupForOr = svc: default:
    let matching = builtins.filter (g: g.ha-group.services ? ${svc}) (builtins.attrValues myGroups);
    in if matching == [] then default else builtins.head matching;

  clusterNodesFor = svc: (groupForOr svc { ha-group = { members = []; network = ""; }; }).ha-group.members;
  networkFor      = svc: (groupForOr svc { ha-group = { members = []; network = ""; }; }).ha-group.network;
in
{
  config = lib.mkIf (myGroups != { }) {
    psyclyx.nixos.derived = {
      patroni = lib.mkIf (hasService "postgresql") {
        dataNetwork = networkFor "postgresql";
        clusterNodes = clusterNodesFor "postgresql";
      };

      redis-sentinel =
        let
          redisNodes = lib.take 3 (clusterNodesFor "redis");
        in
        lib.mkIf (hasService "redis" && builtins.elem hostname redisNodes) {
          dataNetwork = networkFor "redis";
          clusterNodes = redisNodes;
        };

      openbao-cluster = lib.mkIf (hasService "openbao") {
        clusterNodes = clusterNodesFor "openbao";
      };

      seaweedfs = lib.mkIf (hasService "s3" || hasService "webdav") {
        dataNetwork = networkFor "s3";
        masterNodes = lib.take 3 (clusterNodesFor "s3");
      };
    };

    # Service-side toggles (s3/webdav enables) still need to be set on the
    # generic module — those are per-feature flags, not cluster shape.
    psyclyx.nixos.services.seaweedfs = lib.mkIf (hasService "s3" || hasService "webdav") {
      enable = true;
      s3.enable = hasService "s3";
      webdav.enable = hasService "webdav";
    };
  };
}
