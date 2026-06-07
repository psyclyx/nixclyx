# Egregore → PXE projection.
#
# Three things on a PXE server host (one that sets topology.pxe.serve = true):
#   1. Builds a custom iPXE binary with an embedded chain script that
#      fetches a per-MAC script via HTTP after iPXE's own DHCP.
#   2. Populates services.pxe-server.clients with each PXE host's
#      netboot artifacts (kernel + initrd + cmdline), via colmena's
#      cross-host `nodes` arg.
#   3. Adds per-host Kea reservations on the DHCP pool that backs each
#      PXE client's pxeInterface network — boot-file-name = "ipxe.efi",
#      next-server = the PXE server's bind address. Static IP per MAC.
#
# Hosts with boot.mode = "local" are ignored. Hosts with mode = "pxe"
# but no MAC declared on their pxeInterface device are skipped.
{config, lib, nodes ? {}, pkgs, ...}: let
  cfg = config.psyclyx.nixos.topology.pxe;
  eg = config.psyclyx.egregore;
  enabled = cfg.serve;

  hostname = config.psyclyx.nixos.host;
  myEnt = eg.entities.${hostname} or null;
  # Resolved address view folds in gateway-derived addresses, so this
  # works whether the PXE server is the gateway of the network or just
  # an L2 listener on it. Attrs live at the entity root (host type
  # mounts them via mkType.attrs), not under host.attrs.
  myAddrs = if myEnt == null then {} else myEnt.attrs.addresses or {};

  # Address the PXE server should advertise as next-server to clients
  # PXE-booting on this network. Null if the PXE server has no IPv4
  # there — in that case the projection skips the reservation rather
  # than serving cross-VLAN.
  nextServerForNetwork = network:
    (myAddrs.${network} or {}).ipv4 or null;

  pxeHosts = lib.filterAttrs (_: e:
    e.type == "host" && (e.host.boot.mode or "local") == "pxe"
  ) eg.entities;

  # MAC for a particular PXE-eligible interface of a host:
  # host.interfaces.<ifName>.device → host.mac.<device>.
  hostMacOnInterface = hostEnt: ifName: let
    iface = hostEnt.host.interfaces.${ifName} or null;
    dev = if iface != null then iface.device else null;
  in
    if dev != null && (hostEnt.host.mac ? ${dev}) then hostEnt.host.mac.${dev}
    else null;

  hostIpOnInterface = hostEnt: ifName: let
    addr = hostEnt.host.addresses.${ifName} or null;
  in if addr != null then addr.ipv4 else null;

  # Custom iPXE with an embedded chain script. After firmware loads
  # this binary via TFTP, iPXE runs DHCP again to learn next-server,
  # then HTTP-fetches the per-MAC script and chains.
  embedScript = pkgs.writeText "chain.ipxe" ''
    #!ipxe
    echo
    echo psyclyx PXE chainload (iPXE)
    echo
    dhcp || goto retry
    echo MAC: ''${net0/mac}
    echo Next: ''${next-server}
    chain http://''${next-server}:${toString cfg.httpPort}/boot/''${net0/mac:hexhyp}.ipxe || goto retry
    :retry
    echo Boot failed, retrying in 5s...
    sleep 5
    chain --replace --autofree ipxe.efi
  '';

  customIpxe = pkgs.ipxe.override { inherit embedScript; };

  # Spec-URL base the loader fetches its host spec + JWE blobs from.
  # Resolved at boot via ''${next-server} (the iPXE-known PXE host IP)
  # so multi-VLAN setups stay self-consistent.
  specBaseUrl = port: "http://\${next-server}:${toString port}";

  # Two code paths.
  #
  # Default ("disk-backed PXE"): the host's own kernel + standard
  # stage-1 initrd (system.build.{kernel,initialRamdisk}) is served.
  # Stage-1 mounts /nix and /persist directly — from a local pool or
  # NFS — and boots straight into stage-2. No kexec, no squashfs of
  # the system closure baked into the initrd.
  #
  # Loader path: the shared lab-loader's kernel + netbootRamdisk
  # (a squashfs of the loader's closure) is served instead, and the
  # loader's stage-2 fetches a per-host spec, does ZFS/clevis/NFS
  # mounts, and kexecs into the target's real system. Used by hosts
  # that haven't been moved to disk-backed PXE yet — opt in via
  # host.boot.useLoader. Also used as a fallback when no nodeCfg is
  # available for a PXE host (eval-without-colmena).
  mkClient = name: hostEnt: let
    h = hostEnt.host;
    macs = lib.filter (m: m != null)
      (map (n: hostMacOnInterface hostEnt n) h.boot.pxeInterfaces);
    nodeCfg = nodes.${name}.config or null;
    hasNodeCfg = nodeCfg != null;
    useLoader = cfg.loaderSystem != null
                && (h.boot.useLoader || !hasNodeCfg);
    loaderCfg = if useLoader then cfg.loaderSystem else null;
  in
    if macs == [] then null
    else if useLoader then {
      inherit name;
      value = {
        inherit macs;
        kernel = "${loaderCfg.kernel}/bzImage";
        initrd = "${loaderCfg.netbootRamdisk}/initrd";
        cmdline = "init=${loaderCfg.toplevel}/init "
          + "pxe-host=${name} "
          + "pxe-spec-url=${specBaseUrl cfg.httpPort} "
          + "ip=dhcp "
          + lib.concatStringsSep " " (loaderCfg.kernelParams or []);
      };
    }
    else if hasNodeCfg then {
      inherit name;
      value = {
        inherit macs;
        kernel = "${nodeCfg.system.build.kernel}/bzImage";
        # Standard NixOS stage-1 — NOT netbootRamdisk. /nix and
        # /persist come from the host's own storage (a local ZFS
        # pool or NFS), so the initrd just needs the kernel modules
        # and userspace to mount them. No squashfs-of-closure.
        initrd = "${nodeCfg.system.build.initialRamdisk}/initrd";
        # ip=dhcp bootstraps initrd networking from the kernel
        # directly (no systemd-networkd dance), which is what
        # clevis-tang needs to be able to reach the tang server
        # BEFORE the ZFS encryption key load. Relying on initrd
        # systemd-networkd alone was racy here: wait-online would
        # time out, the network-online target would still fire,
        # and the clevis decrypt would then fail with "Error
        # communicating with server" → emergency mode.
        cmdline = "init=${nodeCfg.system.build.toplevel}/init "
          + "ip=dhcp "
          + lib.concatStringsSep " " nodeCfg.boot.kernelParams;
      };
    }
    else null;

  clientPairs = lib.filter (x: x != null)
    (lib.mapAttrsToList mkClient pxeHosts);

  clients = builtins.listToAttrs clientPairs;

  # Per-network Kea reservations. Each host enumerates the networks it
  # is willing to PXE on (boot.pxeInterfaces); we emit a reservation in
  # each of those pools, with next-server pointing at the PXE server's
  # IP *on that same network*. Networks where the PXE server has no
  # address are skipped — we don't want firmware doing a cross-VLAN
  # TFTP that depends on iyr's L2-listener trick.
  hostNetReservations = name: hostEnt:
    lib.filter (r: r != null) (map (ifName: let
      mac = hostMacOnInterface hostEnt ifName;
      ip  = hostIpOnInterface hostEnt ifName;
      nextServer = nextServerForNetwork ifName;
    in
      if mac == null || ip == null || nextServer == null then null
      else {
        network = ifName;
        reservation = {
          "hw-address" = mac;
          "ip-address" = ip;
          hostname = name;
          "next-server" = nextServer;
          "boot-file-name" = "ipxe.efi";
        };
      }
    ) hostEnt.host.boot.pxeInterfaces);

  allReservations = lib.flatten (lib.mapAttrsToList hostNetReservations pxeHosts);

  poolExtraReservations =
    lib.mapAttrs (_: rs: map (r: r.reservation) rs)
      (lib.groupBy (r: r.network) allReservations);

  # PXE-server bind addresses: every IP we used as next-server above.
  bindAddresses = lib.unique
    (map (r: r.reservation."next-server") allReservations);
in {
  options.psyclyx.nixos.topology.pxe = {
    serve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set to true on the host that should run the PXE server. The
        projection then reads every PXE-mode host and populates
        services.pxe-server.clients with their netboot artifacts and
        adds matching Kea reservations. The set of addresses we bind
        on falls out of the per-network reservations.
      '';
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8089;
      description = "HTTP port the PXE server uses (must match pxe-server.httpPort).";
    };

    loaderSystem = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          kernel = lib.mkOption { type = lib.types.path; };
          netbootRamdisk = lib.mkOption { type = lib.types.path; };
          toplevel = lib.mkOption { type = lib.types.path; };
          kernelParams = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      });
      default = null;
      description = ''
        When set, every PXE host is served the same kernel + initrd
        (the lab-loader's); per-host differentiation is via cmdline
        (pxe-host, pxe-spec-url). When null, falls back to per-host
        system.build.netbootRamdisk. Typically set to a record
        derived from `nodes.lab-loader.config.system.build` (see
        configs/pxe.nix in the consumer fleet).
      '';
    };
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.pxe-server = lib.mkIf (clients != {}) {
      enable = true;
      inherit bindAddresses;
      httpPort = cfg.httpPort;
      inherit clients;
      ipxeBinaries = {
        uefi = "${customIpxe}/ipxe.efi";
        bios = "${customIpxe}/undionly.kpxe";
      };
    };

    # Push reservations into the DHCP pools backing each PXE network.
    # Module merging combines this partial pool definition (just the
    # reservations) with the full pool declaration in the host's
    # dhcp.nix (network/ipv4Range).
    psyclyx.nixos.services.dhcp.pools = lib.mapAttrs (_netName: reservations: {
      extraReservations = reservations;
    }) poolExtraReservations;
  };
}
