# Entity type: iSCSI LUN (ZFS zvol exported by one host to others).
#
# Carves the LUN as a first-class fleet noun. The producer (the host whose
# pool backs the zvol) and the consumers (hosts allowed to attach) both
# project from this single record — target config on one side, initiator
# config on the other.
#
# IQN naming, portal selection, ACL string format are projection concerns
# (composed from globals.iscsi.baseIqn + entity names), NOT type fields.
{
  egregoreType = { lib, ... }: {
    name = "lun";
    description = "iSCSI-shared zvol with a producer and consumer hosts.";

    options = {
      sizeGiB = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = ''
          Allocation size in GiB. Required for real luns (asserted
          non-zero below) — the default of 0 only exists so non-lun
          entities don't trip the option-without-default check when
          consumers like psyclyx-link serialize the whole entity tree.
        '';
      };
      pool = lib.mkOption {
        type = lib.types.str;
        default = "tank";
        description = "ZFS pool name on the producer.";
      };
      dataset = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Full dataset path. Null derives "''${pool}/luns/<entity-name>".
          Set explicitly when the producer wants a different layout.
        '';
      };
      network = lib.mkOption {
        type = lib.types.str;
        default = "storage";
        description = "Network entity carrying iSCSI traffic for this LUN.";
      };
      purpose = lib.mkOption {
        type = lib.types.enum [
          "data"
          "scratch"
        ];
        default = "data";
        description = ''
          data — consumer mounts as a regular filesystem at runtime, or
                 the VM that owns the LUN treats it as a block device.
          scratch — ephemeral / discardable.
        '';
      };
      consumers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Host entity names allowed to attach this LUN.";
      };
      readOnly = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      blockSize = lib.mkOption {
        type = lib.types.int;
        default = 4096;
        description = "Logical block size exposed to initiators.";
      };
      mountPoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Where consumers want this LUN mounted. Null means "expose the
          block device but don't auto-mount" (initiator mounts manually,
          or the consumer is a VM treating it as a raw device). Set this
          when the LUN exists for a specific filesystem path.
        '';
      };
      fsType = lib.mkOption {
        type = lib.types.str;
        default = "ext4";
        description = "Filesystem on the LUN. Used both for initiator-side mount fsType and for microvm.nix volumes.";
      };
    };

    attrs =
      name: entity: _top:
      let
        l = entity.lun;
      in
      {
        dataset = if l.dataset != null then l.dataset else "${l.pool}/luns/${name}";
        sizeBytes = l.sizeGiB * 1024 * 1024 * 1024;
        producer = entity.refs.producer or null;
        label = "${toString l.sizeGiB}GiB ${l.purpose} @ ${entity.refs.producer or "<unset>"}";
      };

    assertions =
      name: entity: top:
      let
        l = entity.lun;
        producer = entity.refs.producer or null;
      in
      [
        {
          assertion = producer != null;
          message = "lun '${name}' requires refs.producer";
        }
        {
          assertion = producer == null || (top.entities ? ${producer} && top.entities.${producer}.type == "host");
          message = "lun '${name}' producer '${toString producer}' must be a host entity";
        }
        {
          assertion = top.entities ? ${l.network} && top.entities.${l.network}.type == "network";
          message = "lun '${name}' network '${l.network}' must be a network entity";
        }
        {
          assertion = l.sizeGiB > 0;
          message = "lun '${name}' requires sizeGiB > 0";
        }
      ]
      ++ map (c: {
        assertion = top.entities ? ${c} && top.entities.${c}.type == "host";
        message = "lun '${name}' consumer '${c}' must be a host entity";
      }) l.consumers;
  };
}
