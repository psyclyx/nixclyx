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

  # Cross-host eval: each PXE client's netboot artifacts come from its
  # own NixOS config. nodes is colmena-provided.
  mkClient = name: hostEnt: let
    h = hostEnt.host;
    macs = lib.filter (m: m != null)
      (map (n: hostMacOnInterface hostEnt n) h.boot.pxeInterfaces);
    nodeCfg = nodes.${name}.config or null;
    hasBuild =
      nodeCfg != null
      && nodeCfg ? system
      && nodeCfg.system ? build
      && nodeCfg.system.build ? netbootRamdisk;
  in
    if macs != [] && hasBuild
    then {
      inherit name;
      value = {
        inherit macs;
        kernel = "${nodeCfg.system.build.kernel}/bzImage";
        initrd = "${nodeCfg.system.build.netbootRamdisk}/initrd";
        # init= is the system toplevel's stage-2 init — without it,
        # stage-1 mounts the squashfs but doesn't know which closure
        # to switch into ("failed to find nixos closure" then emergency
        # shell). Matches the cmdline nixpkgs' netboot module emits in
        # its own iPXE script.
        #
        # ip=dhcp bootstraps initrd networking from the kernel directly
        # (no systemd-networkd dance), which is what clevis-tang needs
        # to be able to reach the tang server BEFORE the ZFS encryption
        # key load. Relying on initrd systemd-networkd alone was racy
        # here: wait-online would time out, the network-online target
        # would still fire, and the clevis decrypt would then fail with
        # "Error communicating with server" → emergency mode.
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
  # each of those pools, keyed by that interface's MAC + address.
  # That lets firmware boot order pick any of the host's NICs and still
  # land on the right pool.
  hostNetReservations = name: hostEnt:
    lib.filter (r: r != null) (map (ifName: let
      mac = hostMacOnInterface hostEnt ifName;
      ip  = hostIpOnInterface hostEnt ifName;
    in
      if mac == null || ip == null then null
      else {
        network = ifName;
        reservation = {
          "hw-address" = mac;
          "ip-address" = ip;
          hostname = name;
          "next-server" = cfg.bindAddress;
          "boot-file-name" = "ipxe.efi";
        };
      }
    ) hostEnt.host.boot.pxeInterfaces);

  allReservations = lib.flatten (lib.mapAttrsToList hostNetReservations pxeHosts);

  poolExtraReservations =
    lib.mapAttrs (_: rs: map (r: r.reservation) rs)
      (lib.groupBy (r: r.network) allReservations);
in {
  options.psyclyx.nixos.topology.pxe = {
    serve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set to true on the host that should run the PXE server. The
        projection then reads every PXE-mode host and populates
        services.pxe-server.clients with their netboot artifacts and
        adds matching Kea reservations.
      '';
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      description = ''
        Address the PXE server binds. Reachable from PXE clients on
        the lab VLAN. Returned to clients as next-server in their DHCP
        reservation, so PXE firmware fetches the iPXE binary from here
        via TFTP, then iPXE fetches the chain script from here via HTTP.
      '';
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8089;
      description = "HTTP port the PXE server uses (must match pxe-server.httpPort).";
    };
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.pxe-server = lib.mkIf (clients != {}) {
      enable = true;
      bindAddress = cfg.bindAddress;
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
