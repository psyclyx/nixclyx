# Egregore → iSCSI target/initiator projection.
#
# Reads `lun` entities and projects them into the appropriate service
# config:
#   - If this host is the lun's producer, populate iscsi.target.targets.
#   - If this host is a consumer, populate iscsi.initiator.mounts.
#
# IQNs compose from globals.iscsi.baseIqn + producer + lun name. Portal
# addresses come from the producer's address on the lun's network. All
# of this is derived — hosts only opt in via psyclyx.nixos.topology.iscsi.enable.
{config, lib, ...}: let
  cfg = config.psyclyx.nixos.topology.iscsi;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname} or null;
  enabled = cfg.enable && me != null;

  baseIqn = eg.iscsi.baseIqn or "";

  # All lun entities.
  allLuns = lib.filterAttrs (_: e: e.type == "lun") eg.entities;

  # IQN convention: <base>:<producer>:<lun-name>.
  mkIqn = lunName: producer: "${baseIqn}:${producer}:${lunName}";

  # Initiator IQN convention: <base>:host:<hostname>.
  initiatorIqn = "${baseIqn}:host:${hostname}";

  # Producer-side: lun entities where refs.producer == this host.
  producedLuns = lib.filterAttrs (_: l:
    (l.refs.producer or null) == hostname
  ) allLuns;

  # For each produced lun, the dataset its zvol sits in (e.g.
  # tank/luns/ab-api-state) might be under an encryption root with a
  # clevis-binding (tank/luns is bound on lab-4). target.service needs
  # the binding's unlock unit to run first — find them.
  allBindings = lib.filterAttrs (_: e: e.type == "clevis-binding") eg.entities;
  allDatasets = lib.filterAttrs (_: e: e.type == "zfs-dataset") eg.entities;
  datasetByPath = lib.listToAttrs (lib.mapAttrsToList
    (_: d: lib.nameValuePair d.zfs-dataset.path d) allDatasets);
  bindingForDatasetPath = path:
    let
      hits = lib.filter (b:
        let bds = allDatasets.${b.clevis-binding.protectDataset or ""} or null;
        in bds != null
           && (bds.zfs-dataset.path == path
               || lib.hasPrefix "${bds.zfs-dataset.path}/" path)
      ) (lib.attrValues allBindings);
    in if hits == [] then null else lib.head hits;

  producedLunUnlockUnits = lib.unique (lib.filter (u: u != null) (
    lib.mapAttrsToList (_: l:
      let
        b = bindingForDatasetPath l.attrs.dataset;
      in if b == null then null else b.attrs.unlockUnitName
    ) producedLuns
  ));

  mkTarget = lunName: lun: let
    producer = lun.refs.producer;
  in {
    name = "lun_${lunName}";
    value = {
      iqn = mkIqn lunName producer;
      luns = [{
        device = "/dev/zvol/${lun.attrs.dataset}";
        lun = 0;
        readOnly = lun.lun.readOnly;
      }];
      aclIqns = map (consumer:
        "${baseIqn}:host:${consumer}"
      ) lun.lun.consumers;
    };
  };

  producerTargets = builtins.listToAttrs
    (lib.mapAttrsToList mkTarget producedLuns);

  # Producer-side: bind portals on every address the producer holds on
  # any consumed network.
  producerPortalNetworks = lib.unique (
    lib.mapAttrsToList (_: l: l.lun.network) producedLuns
  );

  producerPortals = lib.flatten (map (netName:
    let
      addrs = me.host.addresses.${netName} or null;
    in
      lib.optional (addrs != null && addrs.ipv4 != null) {
        address = addrs.ipv4;
        network = netName;
      }
  ) producerPortalNetworks);

  # Consumer-side: lun entities where this host is in consumers.
  # Excludes LUNs whose producer is also this host's hypervisor — that's
  # a co-located VM/host pair, and microvm.nix attaches the zvol
  # directly via virtio-blk (see topology/vms.nix). The block device
  # appears in-guest without an iSCSI hop.
  myHypervisor = (me.refs or {}).hypervisor or null;
  consumedLuns = lib.filterAttrs (_: l:
    builtins.elem hostname l.lun.consumers
    && (myHypervisor == null || (l.refs.producer or null) != myHypervisor)
  ) allLuns;

  mkMount = lunName: lun: let
    producer = lun.refs.producer;
    producerEnt = eg.entities.${producer};
    network = lun.lun.network;
    producerAddr = producerEnt.host.addresses.${network}.ipv4;
    isBoot = lun.lun.purpose == "boot";
  in {
    name = "lun_${lunName}";
    value = {
      targetIqn = mkIqn lunName producer;
      portals = [ producerAddr ];
      lun = 0;
      mountpoint = if isBoot then null else "/srv/${lunName}";
      fsType = if isBoot then "ext4" else "ext4";
    };
  };

  consumerMounts = builtins.listToAttrs
    (lib.mapAttrsToList mkMount consumedLuns);
in {
  options.psyclyx.nixos.topology.iscsi = {
    enable = lib.mkEnableOption "project lun entities into SCST target / iSCSI initiator config";
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.iscsi.target = lib.mkIf (producedLuns != {}) {
      enable = true;
      portals = producerPortals;
      targets = producerTargets;
    };

    # target.service can't enumerate zvols whose enclosing encryption
    # root isn't unlocked. Wire the dependency on the binding's
    # generated unlock unit — name comes from the binding's attrs so
    # we never hardcode systemd unit strings down here.
    systemd.services.target = lib.mkIf (producedLuns != {} && producedLunUnlockUnits != []) {
      wants = producedLunUnlockUnits;
      after = producedLunUnlockUnits;
    };

    psyclyx.nixos.services.iscsi.initiator = lib.mkIf (consumedLuns != {}) {
      enable = true;
      inherit initiatorIqn;
      mounts = consumerMounts;
    };

    # Producer-side: ensure the parent zvol dataset exists. Actual zvol
    # creation per LUN is handled by a oneshot before target.service in
    # a follow-up; for now the operator runs `zfs create -V <size> <ds>`
    # manually after pool init.
  };
}
