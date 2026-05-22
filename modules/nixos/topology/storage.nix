# Egregore → ZFS storage projection.
#
# Reads zfs-pool, zfs-dataset, and clevis-binding entities; derives
# everything storage-shaped on each host:
#
#   - For pools I produce: disko block (pool topology + per-dataset
#     create-time options) and zfs-runtime mounts for each dataset
#     I own with a non-null mountpoint.
#   - For clevis-bindings whose protected dataset lives in a pool I
#     produce: boot.initrd.clevis device (if any descendant dataset
#     has neededForBoot) OR a post-boot `zfs-load-key-<name>`
#     systemd one-shot (otherwise). Same JWE blob, different unlock
#     timing.
#   - For datasets I own that have remote consumers (a host whose
#     refs.{nixDataset,persistDataset} points here AND that host
#     isn't me): NFS exports on a producer-chosen network. Consumer
#     fileSystems entries are emitted on the consumer side.
#   - For datasets I consume via refs.{nixDataset,persistDataset}
#     that I don't produce: an NFS mount pointing at the producer's
#     address on the export's network.
#
# Cardinal rule: no entity-name defaults. "lab-4" never appears in
# this file — every host/dataset relationship comes from refs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.topology.storage;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = cfg.enable && hostname != "";

  pools = lib.filterAttrs (_: e: e.type == "zfs-pool") eg.entities;
  datasets = lib.filterAttrs (_: e: e.type == "zfs-dataset") eg.entities;
  bindings = lib.filterAttrs (_: e: e.type == "clevis-binding") eg.entities;

  myPools = lib.filterAttrs (_: p: (p.refs.host or null) == hostname) pools;
  myDatasets = lib.filterAttrs (_: d: (d.attrs.producer or null) == hostname) datasets;

  # Consumers of a given dataset = hosts whose refs.nixDataset or
  # refs.persistDataset names this dataset (excluding the producer
  # itself — a host using its own dataset is a local mount, not a
  # remote consumer).
  consumersOf =
    datasetName:
    let
      isConsumer = h:
        ((h.refs.nixDataset or null) == datasetName
          || (h.refs.persistDataset or null) == datasetName)
        && h.attrs.name != (datasets.${datasetName}.attrs.producer or null);
    in
    lib.filterAttrs (_: h: h.type == "host" && isConsumer h) eg.entities;

  # Strip the pool prefix from a dataset path: "tank/persist/lab-4" → "persist/lab-4".
  stripPoolPrefix =
    poolName: path:
    let
      prefix = "${poolName}/";
    in
    if lib.hasPrefix prefix path
    then lib.removePrefix prefix path
    else path;

  # Pick a host's IPv4 on a network, falling back to null. The address
  # must be the resolved view (h.attrs.addresses) so gateway-derived
  # entries are included.
  hostAddrOn = host: net: ((host.attrs.addresses or { }).${net} or { }).ipv4 or null;

  # Network used to export ZFS datasets to remote consumers. The
  # producer must have an address on this network for it to be usable;
  # the option below picks the one to use per producer.
  exportNetwork = cfg.exportNetwork;

  # ── disko translation ────────────────────────────────────────────

  mkDiskoDataset =
    pool: d:
    let
      shortPath = stripPoolPrefix pool.zfs-pool.name d.zfs-dataset.path;
      props = d.zfs-dataset.properties;
      enc = d.zfs-dataset.encryption;
      encProps = lib.optionalAttrs (enc != null) {
        encryption = enc.cipher;
        keyformat = enc.keyformat;
        keylocation = enc.keylocation;
      };
      mountedAtRuntime = d.zfs-dataset.mountpoint != null;
      diskoOptions =
        (if mountedAtRuntime then { mountpoint = "legacy"; } else { mountpoint = "none"; })
        // props
        // encProps;
    in
    lib.nameValuePair shortPath ({
      type = "zfs_fs";
      options = diskoOptions;
    } // lib.optionalAttrs mountedAtRuntime {
      mountpoint = d.zfs-dataset.mountpoint;
    });

  diskoConfigFor =
    poolName: pool:
    let
      topo = pool.zfs-pool.topology;
      allDisks = lib.flatten (map (v: v.disks) (topo.vdevs or [ ]));
      diskHandles = lib.imap0 (i: d: lib.nameValuePair "ssd${toString i}" d) allDisks;
      handleFor = id: (lib.findFirst (h: h.value.id == id) null diskHandles).name;
      poolDatasets =
        lib.filterAttrs (_: d: (d.refs.pool or null) == poolName) myDatasets;
      diskoDisks = lib.listToAttrs (map (h: lib.nameValuePair h.name {
        type = "disk";
        device = "/dev/disk/by-id/${h.value.id}";
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = pool.zfs-pool.name;
            };
          };
        };
      }) diskHandles);
    in {
      disk = diskoDisks;
      zpool.${pool.zfs-pool.name} = {
        type = "zpool";
        mode = {
          topology.type = "topology";
          topology.vdev = map (v: {
            mode = v.mode;
            members = map (d: handleFor d.id) v.disks;
          }) (topo.vdevs or [ ]);
        };
        rootFsOptions = topo.rootFsOptions or { };
        datasets = lib.listToAttrs (lib.mapAttrsToList (_: d: mkDiskoDataset pool d) poolDatasets);
      };
    };

  diskoMerged =
    lib.foldl' lib.recursiveUpdate { } (lib.mapAttrsToList diskoConfigFor myPools);

  # ── runtime zfs mounts (zfs-runtime sugar) ───────────────────────

  mountsForMyDatasets = lib.mapAttrs' (_: d:
    lib.nameValuePair d.zfs-dataset.path {
      mountpoint = d.zfs-dataset.mountpoint;
      options = [ "defaults" ];
      neededForBoot = d.zfs-dataset.neededForBoot;
    }
  ) (lib.filterAttrs (_: d: d.zfs-dataset.mountpoint != null) myDatasets);

  # ── clevis: initrd vs post-boot ──────────────────────────────────

  # All descendants of a dataset = datasets whose path starts with
  # "<parent>/". Includes the parent itself for the purposes of
  # checking whether ANY of {parent, descendants} needs early boot.
  descendantsAndSelf =
    parentPath:
    lib.filterAttrs (
      _: d:
      d.zfs-dataset.path == parentPath
      || lib.hasPrefix "${parentPath}/" d.zfs-dataset.path
    ) datasets;

  bindingIsInitrd =
    b:
    let
      ds = b.clevis-binding.protectDataset;
      brood = if ds == null then { } else descendantsAndSelf datasets.${ds}.zfs-dataset.path;
    in
    lib.any (d: d.zfs-dataset.neededForBoot) (lib.attrValues brood);

  myBindings = lib.filterAttrs (
    _: b:
    b.clevis-binding.protectDataset != null
    && (datasets.${b.clevis-binding.protectDataset}.attrs.producer or null) == hostname
  ) bindings;

  initrdBindings = lib.filterAttrs (_: b: bindingIsInitrd b) myBindings;
  postBootBindings = lib.filterAttrs (_: b: !(bindingIsInitrd b)) myBindings;

  initrdClevisDevices = lib.mapAttrs' (_: b:
    lib.nameValuePair
      datasets.${b.clevis-binding.protectDataset}.zfs-dataset.path
      { secretFile = b.clevis-binding.secretFile; }
  ) (lib.filterAttrs (_: b: b.clevis-binding.secretFile != null) initrdBindings);

  mkPostBootKeyService =
    _: b:
    let
      dsEnt = datasets.${b.clevis-binding.protectDataset};
      poolEnt = pools.${dsEnt.refs.pool};
      dsPath = dsEnt.zfs-dataset.path;
      # Consumers find this unit name via b.attrs.unlockUnitName.
      unitName = lib.removeSuffix ".service" b.attrs.unlockUnitName;
    in
    lib.nameValuePair unitName {
      description = "Unseal ${dsPath} via clevis";
      after = [ "zfs-import-${poolEnt.zfs-pool.name}.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.clevis pkgs.zfs pkgs.curl pkgs.jose ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript unitName ''
          set -euo pipefail
          if [ "$(zfs get -H -o value keystatus ${dsPath})" = available ]; then
            exit 0
          fi
          clevis decrypt < ${b.clevis-binding.secretFile} | zfs load-key -L prompt ${dsPath}
        '';
      };
    };

  postBootKeyServices = lib.listToAttrs (
    lib.mapAttrsToList mkPostBootKeyService
      (lib.filterAttrs (_: b: b.clevis-binding.secretFile != null) postBootBindings)
  );

  # ── NFS exports (producer side) ──────────────────────────────────

  # For each of my datasets that has remote consumers, an exports entry
  # per consumer. Address comes from the consumer's IP on exportNetwork;
  # we skip consumers without an address there (the projection isn't a
  # firewall — we don't fake reachability).
  mkExportsForDataset =
    _: d:
    let
      cons = consumersOf d.attrs.name;
    in
    map (c: {
      path = d.zfs-dataset.mountpoint;
      consumer = {
        address = hostAddrOn c exportNetwork;
        readOnly = false;
      };
    }) (lib.filter (c: hostAddrOn c exportNetwork != null) (lib.attrValues cons));

  myDatasetExports = lib.flatten (lib.mapAttrsToList mkExportsForDataset
    (lib.filterAttrs (_: d: d.zfs-dataset.mountpoint != null
      && consumersOf d.attrs.name != { }) myDatasets));

  # Group per-path so a dataset with multiple consumers becomes one
  # exports line with all client addresses. Output shape matches
  # psyclyx.nixos.services.nfs-server.exports (list of { path; clients; }).
  exportsGrouped = lib.groupBy (e: e.path) myDatasetExports;
  myExports = lib.mapAttrsToList (path: entries: {
    inherit path;
    clients = map (e: e.consumer) entries;
  }) exportsGrouped;

  # ── NFS mounts (consumer side) ───────────────────────────────────

  me = if hostname == "" then null else eg.entities.${hostname} or null;
  myNixDsRef = if me == null then null else me.refs.nixDataset or null;
  myPersistDsRef = if me == null then null else me.refs.persistDataset or null;

  remoteConsumerMounts =
    let
      mountOf = role: dsRef: localMount:
        let
          d = if dsRef == null then null else datasets.${dsRef} or null;
          producer = if d == null then null else d.attrs.producer or null;
          producerEnt = if producer == null then null else eg.entities.${producer} or null;
          producerAddr = if producerEnt == null then null else hostAddrOn producerEnt exportNetwork;
        in
        if d == null || producer == null || producer == hostname || producerAddr == null
        then null
        else {
          inherit role localMount;
          remote = "${producerAddr}:${d.zfs-dataset.mountpoint}";
          neededForBoot = true;
        };
      raw = [
        (mountOf "nix" myNixDsRef "/nix")
        (mountOf "persist" myPersistDsRef "/persist")
      ];
    in lib.filter (m: m != null) raw;

  nfsFileSystems = lib.listToAttrs (map (m:
    lib.nameValuePair m.localMount {
      device = m.remote;
      fsType = "nfs4";
      options = [ "noatime" "nfsvers=4.2" ];
      neededForBoot = m.neededForBoot;
    }
  ) remoteConsumerMounts);

  amProducer = myPools != { };
  amConsumer = remoteConsumerMounts != [ ];
in
{
  options.psyclyx.nixos.topology.storage = {
    enable = lib.mkEnableOption ''
      project zfs-pool / zfs-dataset / clevis-binding entities into
      disko, zfs-runtime mounts, initrd clevis (or post-boot
      key-load), and producer/consumer NFS wiring.
    '';
    exportNetwork = lib.mkOption {
      type = lib.types.str;
      default = "lab";
      description = ''
        Network entity name carrying ZFS-derived NFS exports. Producer
        binds, consumers reach via the address on this network.
      '';
    };
  };

  config = lib.mkIf enabled (lib.mkMerge [
    # Producer side: disko + runtime mounts + clevis.
    (lib.mkIf amProducer {
      disko.devices = diskoMerged;
      psyclyx.nixos.filesystems.zfs-runtime.datasets = mountsForMyDatasets;
      boot.initrd.clevis = lib.mkIf (initrdClevisDevices != { }) {
        enable = true;
        useTang = true;
        devices = initrdClevisDevices;
      };
      systemd.services = postBootKeyServices;
      psyclyx.nixos.services.nfs-server.exports = myExports;
    })

    # Consumer side: NFS root for /nix and /persist.
    (lib.mkIf amConsumer {
      fileSystems = nfsFileSystems;
    })
  ]);
}
