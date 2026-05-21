# Egregore → lab-loader spec projection.
#
# Runs on PXE-server hosts. For each PXE-mode host, derives a JSON
# spec describing what the loader should do at boot: which datasets
# to import/decrypt/mount (or NFS-mount), and where to find the
# system profile to kexec into. Writes the specs into
# services.pxe-server.{hostSpecs,jweBlobs} so the existing static
# HTTP can serve them.
#
# No fleet-specific defaults here: producer/consumer relationships
# all come from refs.
{ config, lib, pkgs, ... }:
let
  cfg = config.psyclyx.nixos.topology.loader-spec;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = cfg.enable && hostname != "";

  bindings = lib.filterAttrs (_: e: e.type == "clevis-binding") eg.entities;
  datasets = lib.filterAttrs (_: e: e.type == "zfs-dataset") eg.entities;
  pools = lib.filterAttrs (_: e: e.type == "zfs-pool") eg.entities;

  pxeHosts = lib.filterAttrs (_: e:
    e.type == "host" && (e.host.boot.mode or "local") == "pxe"
  ) eg.entities;

  # ── Helpers ──────────────────────────────────────────────────────

  # All datasets in a pool. Used to find what clevis-bindings cover.
  datasetsInPool = poolName: lib.filterAttrs (_: d: (d.refs.pool or null) == poolName) datasets;

  # The encryption root ancestor of a dataset path within its pool,
  # if any. Returns the dataset *entity* that's the closest ancestor
  # (including self) marked as an encryption root, or null.
  enclosingEncRoot = dsEnt:
    let
      poolName = dsEnt.refs.pool or null;
      siblings = if poolName == null then { } else datasetsInPool poolName;
      myPath = dsEnt.zfs-dataset.path;
      ancestors = lib.filterAttrs (_: d:
        d.zfs-dataset.encryption != null
        && (d.zfs-dataset.path == myPath
            || lib.hasPrefix "${d.zfs-dataset.path}/" myPath)
      ) siblings;
      sorted = lib.sort
        (a: b: lib.stringLength a.zfs-dataset.path > lib.stringLength b.zfs-dataset.path)
        (lib.attrValues ancestors);
    in
    if sorted == [ ] then null else lib.head sorted;

  # The clevis-binding entity protecting an encryption-root dataset,
  # if one exists. Multiple bindings on the same root would be a data
  # error; we just pick the first.
  bindingFor = encRootName:
    let
      hits = lib.filterAttrs (_: b: b.clevis-binding.protectDataset == encRootName) bindings;
    in
    if hits == { } then null else lib.head (lib.attrValues hits);

  # IP of a host on a given network, or null.
  hostAddrOn = host: net: ((host.attrs.addresses or { }).${net} or { }).ipv4 or null;

  # ── Per-host spec generation ─────────────────────────────────────

  # Produce a list of steps for one consumed dataset (the host's
  # nixDataset or persistDataset), tagged with the target mount point
  # on the loader (/mnt-nix or /mnt-persist).
  stepsForConsumption = host: dsName: localTo:
    let
      dsEnt = datasets.${dsName} or null;
      producer = if dsEnt == null then null else dsEnt.attrs.producer;
      hostName = host.attrs.name;
    in
    if dsEnt == null then [ ]
    else if producer == hostName
    then
      # Local: zfs import (idempotent per pool — dedup later), clevis
      # decrypt the enclosing encryption root if any, then mount.
      let
        encRoot = enclosingEncRoot dsEnt;
        encRootBinding = if encRoot == null then null else bindingFor encRoot.attrs.name;
        importStep = {
          op = "zfs-import";
          pool = pools.${dsEnt.refs.pool}.zfs-pool.name;
        };
        clevisStep = lib.optional (encRootBinding != null) {
          op = "clevis-decrypt-zfs-key";
          dataset = encRoot.zfs-dataset.path;
          # Relative — resolved against pxe-spec-url at fetch time.
          jwePath = "/jwe/${encRootBinding.attrs.name}.jwe";
        };
        mountStep = {
          op = "zfs-mount-bind";
          dataset = dsEnt.zfs-dataset.path;
          to = localTo;
        };
      in [ importStep ] ++ clevisStep ++ [ mountStep ]
    else
      # Remote: NFS-mount from the producer's lab-network address.
      let
        producerEnt = eg.entities.${producer};
        producerAddr = hostAddrOn producerEnt cfg.exportNetwork;
      in
      if producerAddr == null then [ ]
      else [ {
        op = "nfs-mount";
        from = "${producerAddr}:${dsEnt.zfs-dataset.mountpoint}";
        to = localTo;
        options = [ "nfsvers=4.2" "noatime" ];
      } ];

  # Dedup `zfs-import` and `clevis-decrypt-zfs-key` steps while
  # preserving the order of first appearance. The mount-bind steps
  # are unique per-dataset so they don't need dedup.
  dedupSteps = steps:
    let
      keyOf = s: builtins.toJSON {
        inherit (s) op;
        pool = s.pool or "";
        dataset = s.dataset or "";
      };
    in
    lib.foldl' (acc: s:
      if builtins.any (a: keyOf a == keyOf s) acc
      then acc
      else acc ++ [ s ]
    ) [ ] steps;

  specFor = host:
    let
      nixSteps = stepsForConsumption host (host.refs.nixDataset or "") "/mnt-nix";
      persistSteps = stepsForConsumption host (host.refs.persistDataset or "") "/mnt-persist";
      allSteps = dedupSteps (nixSteps ++ persistSteps);
    in {
      name = host.attrs.name;
      steps = allSteps;
      kexecProfile = "/mnt-persist/var/nix/profiles/system";
    };

  hostSpecs = lib.mapAttrs (_: h: builtins.toJSON (specFor h)) pxeHosts;

  # JWE blobs we need to expose. Collected across all clevis-bindings
  # whose protected dataset's producer is a PXE host (since only
  # those bindings are reachable via the loader).
  pxeHostnames = lib.attrNames pxeHosts;
  bindingsToServe = lib.filterAttrs (_: b:
    b.clevis-binding.protectDataset != null
    && b.clevis-binding.secretFile != null
    && (let
         d = datasets.${b.clevis-binding.protectDataset} or null;
       in d != null && builtins.elem d.attrs.producer pxeHostnames)
  ) bindings;
  jweBlobs = lib.mapAttrs (_: b: b.clevis-binding.secretFile) bindingsToServe;
in
{
  options.psyclyx.nixos.topology.loader-spec = {
    enable = lib.mkEnableOption ''
      project per-host lab-loader specs (and the JWE blobs they
      reference) into pxe-server's static-HTTP surface.
    '';
    exportNetwork = lib.mkOption {
      type = lib.types.str;
      default = "lab";
      description = "Network whose addresses the loader uses to reach producers (NFS, JWE fetch).";
    };
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.pxe-server = {
      inherit hostSpecs jweBlobs;
    };
  };
}
