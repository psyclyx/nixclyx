# Egregore → iSCSI target/initiator projection.
#
# Reads `lun` entities and projects them into the appropriate service
# config:
#   - If this host is the lun's producer, populate scst.targets.
#   - If this host is a consumer, populate iscsi-initiator.mounts.
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

  mkTarget = lunName: lun: let
    producer = lun.refs.producer;
  in {
    name = "lun_${lunName}";
    value = {
      iqn = mkIqn lunName producer;
      luns = [{
        device = "/dev/zvol/${lun.attrs.dataset}";
        lun = 0;
        blockSize = lun.lun.blockSize;
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
  consumedLuns = lib.filterAttrs (_: l:
    builtins.elem hostname l.lun.consumers
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
    psyclyx.nixos.services.iscsi.scst = lib.mkIf (producedLuns != {}) {
      portals = producerPortals;
      targets = producerTargets;
    };

    psyclyx.nixos.services.iscsi.initiator = lib.mkIf (consumedLuns != {}) {
      inherit initiatorIqn;
      mounts = consumerMounts;
    };

    # Producer-side: ensure the parent zvol dataset exists. Actual zvol
    # creation per LUN is handled by a oneshot before scst.service in a
    # follow-up; for now the operator runs `zfs create -V <size> <ds>`
    # manually after pool init.
  };
}
