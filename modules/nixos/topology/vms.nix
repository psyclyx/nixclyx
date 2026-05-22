# Egregore → microvm.nix projection.
#
# Reads `host` entities whose `refs.hypervisor` points at this host
# and emits matching `microvm.vms.<name>` entries:
#   - `microvm.volumes` for every `lun` entity this host produces and
#     the VM consumes. Each LUN is attached as virtio-blk against the
#     zvol on the host — no iSCSI hop, since `topology/iscsi.nix` skips
#     co-located VM consumers (they get the block device directly).
#   - `microvm.interfaces` — one macvtap on the host's lab-network NIC,
#     using the VM's declared MAC. The VM gets a first-class lab-VLAN
#     address (DHCP via Kea on iyr, per the host type's address mode).
#   - `networking.hostName` from the entity name.
#
# Per-VM service config (which angelbeats/auth/etc. units to enable,
# where to find sops paths, NFS mounts, …) is supplied by the consumer
# via `psyclyx.nixos.topology.vms.guests.<name>` — a NixOS module that
# imports the right module sets and wires the VM. The projection
# merges its own derived bits in via lib.mkMerge.
{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.topology.vms;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname} or null;
  enabled = cfg.enable && me != null;

  # VMs whose hypervisor is this host.
  myVms = lib.filterAttrs (
    _: e: e.type == "host" && (e.refs.hypervisor or null) == hostname
  ) eg.entities;

  # LUNs we produce that a given VM consumes.
  vmLuns =
    vmName:
    lib.filterAttrs (
      _: l:
      l.type == "lun"
      && (l.refs.producer or null) == hostname
      && builtins.elem vmName l.lun.consumers
    ) eg.entities;

  mkVolume = lunName: lun: {
    image = "/dev/zvol/${lun.attrs.dataset}";
    mountPoint = lun.lun.mountPoint;
    fsType = lun.lun.fsType;
    autoCreate = false;
    label = lunName;
    # microvm.nix declares `size` without a default, so we must pass it
    # even though autoCreate=false means it's never read.
    size = lun.lun.sizeGiB * 1024;
  };

  vmVolumes = vmName: lib.mapAttrsToList mkVolume (vmLuns vmName);

  # Resolve a VM's MAC on a given network via the same convention the
  # DHCP projection uses: interfaces.<net>.device → mac.<device>.
  vmMacOnNetwork =
    vmName: network:
    let
      vm = eg.entities.${vmName};
      iface = vm.host.interfaces.${network} or null;
      dev = if iface != null && iface.device != "" then iface.device else network;
    in
    vm.host.mac.${dev} or null;

  vmMac = vmName: vmMacOnNetwork vmName "lab";

  # Host's lab-network device — the NIC the macvtap parents on.
  myLabDev =
    let
      iface = me.host.interfaces.lab or null;
    in
    if iface == null then null else iface.device;

  mkInterfaces = vmName: [
    {
      type = "macvtap";
      id = "vm-${vmName}";
      mac = vmMac vmName;
      macvtap = {
        link = myLabDev;
        mode = "bridge";
      };
    }
  ];

  # nfs-exports we produce that a given VM consumes — these become
  # virtiofs shares instead of NFS mounts, since the VM can't reach
  # its own hypervisor through macvtap (the macvtap parent device
  # filters traffic between host and child interfaces). The skip on
  # the consumer side lives in topology/nfs.nix.
  vmNfsExports =
    vmName:
    lib.filterAttrs (
      _: e:
      e.type == "nfs-export"
      && (e.refs.producer or null) == hostname
      && builtins.elem vmName e.nfs-export.consumers
      && (e.nfs-export.mountAt or null) != null
    ) eg.entities;

  mkNfsShare = expName: e: {
    source = e.nfs-export.path;
    mountPoint = e.nfs-export.mountAt;
    tag = "nfs-${expName}";
    proto = "virtiofs";
    readOnly = e.nfs-export.readOnly;
  };

  vmShares = vmName: [
    {
      source = "/nix/store";
      mountPoint = "/nix/store";
      tag = "ro-store";
      proto = "virtiofs";
    }
  ] ++ (lib.mapAttrsToList mkNfsShare (vmNfsExports vmName));

  mkVm =
    vmName: vm:
    lib.nameValuePair vmName {
      autostart = true;
      restartIfChanged = true;
      # Guests instantiate their own nixpkgs (with their own
      # `nixpkgs.config` + overlays from the imported module set).
      # The default of inheriting the host's externally-supplied pkgs
      # triggers a NixOS assertion when downstream modules touch
      # `nixpkgs.config`, which the nixclyx common module does.
      pkgs = null;
      config = lib.mkMerge [
        (cfg.guests.${vmName} or { })
        {
          networking.hostName = lib.mkDefault vmName;
          microvm = {
            mem = lib.mkDefault cfg.defaults.memMiB;
            vcpu = lib.mkDefault cfg.defaults.vcpu;
            hypervisor = lib.mkDefault cfg.hypervisor;
            volumes = vmVolumes vmName;
            interfaces = mkInterfaces vmName;
            # Shares from host:
            #   - /nix/store: avoids baking the closure into the VM
            #     image (microvm.nix flips `storeOnDisk` off whenever
            #     a share's source is /nix/store).
            #   - nfs-exports the hypervisor produces and this VM
            #     consumes: handed in directly, avoiding the macvtap
            #     VM-can't-reach-host limitation.
            shares = vmShares vmName;
          };
          # Rename the guest's lone virtio-net interface to the device
          # name declared in egregore for the lab network (e.g. "net0").
          # The fleet network projection keys its networkd units by
          # interface NAME, so without this rename DHCP never fires in
          # the guest. Matching by Driver=virtio_net is fine here:
          # microvm guests get a single NIC (one macvtap parented to
          # the host's lab interface).
          systemd.network.links = let
            labIface = (eg.entities.${vmName}.host.interfaces.lab or null);
            linkName = if labIface == null then null else labIface.device;
          in lib.optionalAttrs (linkName != null && linkName != "") {
            "10-${linkName}" = {
              matchConfig.Driver = "virtio_net";
              linkConfig.Name = linkName;
            };
          };
        }
      ];
    };

  assertions = lib.flatten (
    lib.mapAttrsToList (
      vmName: _:
      [
        {
          assertion = vmMac vmName != null;
          message = "VM '${vmName}' must declare host.mac.lab so the macvtap interface has a MAC.";
        }
        {
          assertion = myLabDev != null;
          message = "Hypervisor '${hostname}' must declare host.interfaces.lab.device to back VM macvtap interfaces.";
        }
      ]
      ++ lib.mapAttrsToList (lunName: lun: {
        assertion = lun.lun.mountPoint != null;
        message = "lun '${lunName}' is consumed by VM '${vmName}' — it needs lun.mountPoint set so microvm.nix knows where to mount it in the guest.";
      }) (vmLuns vmName)
    ) myVms
  );
  # Order each microvm@<vm>.service after its LUNs' format units, so
  # the guest doesn't try to mount an unformatted block device at
  # boot. The zvol-provision projection emits zfs-format-<lun>; we
  # just wire the dependency.
  #
  # Also extend restartTriggers to the runner derivation. Upstream
  # microvm.nix only triggers restart on `guestConfig.system.build.toplevel`,
  # which misses host-side changes — share args (e.g. virtiofsd
  # `--readonly`), volume layout, interface config — all of which live
  # in the runner. Without this, flipping an nfs-export's `readOnly`
  # rebuilds the runner, install-microvm-<vm> swings the `current`
  # symlink, but neither microvm@ nor microvm-virtiofsd@ (which is
  # partOf microvm@) gets restarted, so the live virtiofsd keeps the
  # stale args.
  microvmServiceDeps = lib.mapAttrs' (
    vmName: _:
    let
      lunNames = builtins.attrNames (vmLuns vmName);
      formatUnits = map (lun: "zfs-format-${lun}.service") lunNames;
      runner = config.microvm.vms.${vmName}.config.config.microvm.declaredRunner;
    in
    lib.nameValuePair "microvm@${vmName}" {
      after = formatUnits;
      requires = formatUnits;
      restartTriggers = [ runner ];
    }
  ) myVms;
in
{
  options.psyclyx.nixos.topology.vms = {
    enable = lib.mkEnableOption ''
      project hosts with refs.hypervisor = me into microvm.vms.<name>.
      Requires `microvm.host.enable = true` (handled by lab-4 / any
      future hypervisor's own config).
    '';

    hypervisor = lib.mkOption {
      type = lib.types.enum [
        "qemu"
        "cloud-hypervisor"
        "firecracker"
        "stratovirt"
      ];
      default = "qemu";
      description = "microvm.nix hypervisor backend used as the default for each guest.";
    };

    defaults.memMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1024;
      description = "Default guest memory in MiB. Overridable per-VM by the guest module setting `microvm.mem`.";
    };

    defaults.vcpu = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Default guest vCPU count. Overridable per-VM by `microvm.vcpu`.";
    };

    guests = lib.mkOption {
      type = lib.types.attrsOf lib.types.deferredModule;
      default = { };
      description = ''
        Per-VM NixOS module. Each module is responsible for importing
        the microvm guest module, any nixclyx/privclyx module sets it
        needs, and the per-service enable + wire config. The projection
        merges in `microvm.volumes`/`microvm.interfaces` and
        `networking.hostName` via mkMerge with mkDefault, so the guest
        module can still override anything.
      '';
    };
  };

  config = lib.mkIf enabled {
    inherit assertions;
    microvm.vms = builtins.listToAttrs (lib.mapAttrsToList mkVm myVms);
    systemd.services = microvmServiceDeps;
  };
}
