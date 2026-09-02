# Egregore → ZFS storage projection.
#
# Reads zfs-pool, zfs-dataset, and clevis-binding entities; derives
# everything storage-shaped on each host:
#
#   - For pools I produce: disko block (pool topology + per-dataset
#     create-time options), a fileSystems entry for each dataset I own
#     with a non-null mountpoint, and the pool-import classification —
#     a pool is a `filesystems.zfs.dataPools` entry (imported post-boot)
#     unless one of its datasets is neededForBoot, in which case initrd
#     imports it. disko and mounts are individually gateable for hosts
#     whose on-disk layout the projection doesn't describe.
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
  nodes ? { },
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.derived.storage;
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

  # ── runtime zfs mounts ───────────────────────────────────────────

  # Datasets I own with a mountpoint become explicit fileSystems entries.
  # Anything not needed for boot gets nofail + a short device timeout so a
  # missing pool degrades to a failed mount rather than blocking the boot.
  # Only datasets NixOS itself mounts. A "pam" dataset is real and has a
  # mountpoint, but must stay out of fileSystems — systemd would try to
  # mount it at boot, before pam_zfs_key has loaded the key.
  myMountedDatasets = lib.filterAttrs
    (_: d: d.zfs-dataset.mountpoint != null && d.zfs-dataset.mountedBy == "fileSystems")
    myDatasets;

  fsForMyDatasets = lib.mapAttrs' (_: d:
    lib.nameValuePair d.zfs-dataset.mountpoint {
      device = d.zfs-dataset.path;
      fsType = "zfs";
      # nofail keeps a non-boot dataset from failing the boot outright.
      # Never for "/": a root that silently doesn't mount is unbootable in
      # a much worse way, so guard it here rather than trusting the data.
      options = [ "defaults" ]
        ++ lib.optionals
          (!d.zfs-dataset.neededForBoot && d.zfs-dataset.mountpoint != "/") [
            "nofail"
            "x-systemd.device-timeout=10s"
          ];
      neededForBoot = d.zfs-dataset.neededForBoot;
    }
  ) myMountedDatasets;

  # Datasets mounted by pam_zfs_key at login rather than by systemd at boot.
  myPamDatasets = lib.filterAttrs (_: d: d.zfs-dataset.mountedBy == "pam") myDatasets;

  # ── pool import classification ───────────────────────────────────

  # A pool I produce is imported in initrd iff one of its datasets is needed
  # for boot; otherwise it's imported post-boot by a stage-2
  # zfs-import-<pool>.service. That's exactly `filesystems.zfs.dataPools`,
  # which pins those units to boot-time only — see that option for why.
  #
  # Deriving it here rather than in the generic module is the point: the
  # neededForBoot facts are already declared per dataset, so this needs no
  # reconstruction of nixpkgs' own root/data pool split.
  datasetsOfPool = poolEntName:
    lib.filterAttrs (_: d: (d.refs.pool or null) == poolEntName) myDatasets;

  poolIsBootCritical = poolEntName:
    lib.any (d: d.zfs-dataset.neededForBoot)
      (lib.attrValues (datasetsOfPool poolEntName));

  myDataPools = lib.listToAttrs (lib.mapAttrsToList
    (_: p: lib.nameValuePair p.zfs-pool.name { })
    (lib.filterAttrs (poolEntName: _: !(poolIsBootCritical poolEntName)) myPools));

  # The complement: pools initrd imports. These two partition my pools, and
  # only these have initrd import units to configure.
  myRootPools = lib.mapAttrsToList (_: p: p.zfs-pool.name)
    (lib.filterAttrs (poolEntName: _: poolIsBootCritical poolEntName) myPools);

  # Encryption roots initrd must unlock.
  #
  # An encryption root qualifies if IT or ANYTHING UNDER IT is needed for
  # boot — children inherit the parent's key, so a dataset can be
  # neededForBoot while the root actually holding its key is not. Filtering
  # on the root's own neededForBoot misses exactly that case (a /persist
  # nested under an unmounted encryption root) and leaves the mount with no
  # key. Same subtree test as `bindingIsInitrd` uses for clevis, for the
  # same reason.
  #
  # Naming datasets rather than pools is required, not cosmetic: nixpkgs
  # runs `zfs list` WITHOUT -r over this list (tasks/filesystems/zfs.nix,
  # getKeyLocations), so a pool name only ever matches the pool's own top
  # dataset. Naming a pool whose encryption roots are children silently
  # unlocks nothing.
  #
  # "pam" datasets are excluded: their key comes from the login password at
  # session open, so prompting for them in initrd would defeat the point.
  encryptionRootNeededForBoot = d:
    lib.any (x: x.zfs-dataset.neededForBoot)
      (lib.attrValues (descendantsAndSelf d.zfs-dataset.path));

  myEncryptionRoots = lib.mapAttrsToList (_: d: d.zfs-dataset.path)
    (lib.filterAttrs
      (_: d:
        d.zfs-dataset.encryption != null
        && d.zfs-dataset.mountedBy != "pam"
        && encryptionRootNeededForBoot d)
      myDatasets);

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
  # per consumer per address they hold. We need every address (not just
  # the one on exportNetwork) in the ACL because a consumer's *source*
  # IP at mount time depends on which interface its initrd brought up
  # first — e.g. lab-3 in initrd only has eno1 (main, 10.0.10.13) up
  # before the 10G NIC firmware loads. If the export only allowed the
  # consumer's lab-VLAN address, NFS would reject the mount.
  consumerAddrs = host:
    lib.filter (a: a != null)
      (lib.mapAttrsToList (_: a: a.ipv4 or null)
        (host.attrs.addresses or { }));

  mkExportsForDataset =
    _: d:
    let
      cons = consumersOf d.attrs.name;
    in
    lib.flatten (map (c:
      map (addr: {
        path = d.zfs-dataset.mountpoint;
        consumer = { address = addr; readOnly = false; };
      }) (consumerAddrs c)
    ) (lib.attrValues cons));

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
      # `nfs` (not `nfs4`) is the canonical fsType these days; the
      # actual protocol version comes from the nfsvers= option below.
      # Using "nfs4" yields a kernel `NFS: mount program didn't pass
      # remote address` error at mount time.
      fsType = "nfs";
      options = [ "noatime" "nfsvers=4.2" ];
      neededForBoot = m.neededForBoot;
    }
  ) remoteConsumerMounts);

  amProducer = myPools != { };
  amConsumer = remoteConsumerMounts != [ ];

  # NFS /nix consumers' toplevels: pull each remote consumer's
  # `system.build.toplevel` into my system closure so that
  # `colmena apply --on <me>` ships their store paths to my Nix
  # store automatically. Without this, lab-1..3 boot finding
  # `init=/nix/store/<X>/init` on cmdline, NFS-mount /nix from me,
  # and `X` isn't there yet — first-boot fails until an operator
  # manually `nix copy`s. Scoped to datasets I produce whose
  # mountpoint is `/nix` (since the consumer's toplevel lives in
  # the nix store, not in /persist).
  nixConsumerToplevels = let
    myNixDatasets = lib.filterAttrs
      (_: d: d.zfs-dataset.mountpoint == "/nix")
      myDatasets;
    consumerNames = lib.unique (lib.concatMap
      (d: lib.attrNames (consumersOf d.attrs.name))
      (lib.attrValues myNixDatasets));
    nodeToplevel = name:
      let nodeCfg = nodes.${name}.config or null;
      in if nodeCfg == null then null
         else nodeCfg.system.build.toplevel;
  in
    lib.filter (p: p != null) (map nodeToplevel consumerNames);
in
{
  options.psyclyx.nixos.derived.storage = {
    enable = lib.mkEnableOption ''
      project zfs-pool / zfs-dataset / clevis-binding entities into
      disko, fileSystems entries, pool-import classification, initrd
      clevis (or post-boot key-load), and producer/consumer NFS wiring.
    '';
    disko.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to emit disko config for pools this host produces. The
        translation assumes whole-disk GPT pools; turn it off on hosts whose
        pools were partitioned by hand (EFI + swap + zfs on one disk), where
        the emitted layout would not describe reality. Note disko's
        `enableConfig` also derives `fileSystems`, so a wrong layout here is
        not inert.
      '';
    };

    mounts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to emit `fileSystems` entries for datasets this host owns.
        Turn it off where mounts are declared by hand — e.g. a dataset that
        must not be in `fileSystems` at all because PAM mounts it at login.
      '';
    };

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
    # Producer side: pool classification + clevis (+ disko and mounts where
    # this host's layout actually matches what the projection emits).
    (lib.mkIf amProducer {
      # Pure derived metadata — safe even where disko/mounts are hand-managed.
      psyclyx.nixos.filesystems.zfs = {
        pools = myRootPools;
        dataPools = myDataPools;
        encryptionRoots = myEncryptionRoots;
        explicitMounts = cfg.mounts.enable;
      };

      # A dataset declared mountedBy = "pam" is only mountable if pam_zfs_key
      # is actually wired into the PAM stack.
      security.pam.zfs.enable = lib.mkIf (myPamDatasets != { }) true;
      # dataPools are by construction the post-boot pools, which is exactly
      # what extraPools means for a pool with no mounted dataset of its own.
      boot.zfs.extraPools = lib.attrNames myDataPools;

      boot.initrd.clevis = lib.mkIf (initrdClevisDevices != { }) {
        enable = true;
        useTang = true;
        devices = initrdClevisDevices;
      };
      systemd.services = postBootKeyServices;
      psyclyx.nixos.services.nfs-server.exports = myExports;
      system.extraDependencies = nixConsumerToplevels;
    })

    (lib.mkIf (amProducer && cfg.disko.enable) {
      disko.devices = diskoMerged;
    })

    (lib.mkIf (amProducer && cfg.mounts.enable) {
      fileSystems = fsForMyDatasets;
    })

    # Consumer side: NFS root for /nix and /persist.
    (lib.mkIf amConsumer {
      fileSystems = nfsFileSystems;
    })
  ]);
}
