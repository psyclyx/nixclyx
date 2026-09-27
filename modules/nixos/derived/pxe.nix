# Egregore → PXE projection.
#
# Three things on a PXE server host (one that sets derived.pxe.serve =
# true):
#   1. Builds a custom iPXE binary with an embedded chain script that
#      fetches a per-MAC script via HTTP after iPXE's own DHCP.
#   2. Populates services.pxe-server.clients with each PXE host's
#      netboot artifacts (kernel + initrd + cmdline).
#   3. Adds per-host Kea reservations on the DHCP pool that backs each
#      PXE client's pxeInterface network — boot-file-name = "ipxe.efi",
#      next-server = the PXE server's bind address. Static IP per MAC.
#      derived/dhcp.nix skips these hosts on those networks so the
#      reservation exists exactly once — two reservations for one MAC
#      is something Kea rejects.
#
# The artifacts are one generic rescue system built from this host's
# own nixpkgs (`pkgs.path`) — never another host's evaluated config.
# The projection this replaces read
# `nodes.<host>.config.system.build.{kernel,initialRamdisk,toplevel}`
# through colmena's cross-host `nodes` arg, which made every PXE
# server unevaluatable outside a hive; that is what got lab netboot
# dropped (e86f3cb7). A generic image is also what recovery needs:
# PXE is how borked machines get fixed, so it cannot depend on those
# machines' own configs evaluating.
#
# Hosts with boot.mode = "local" are ignored. Hosts with mode = "pxe"
# but no MAC declared on their pxeInterface device are skipped.
{
  config,
  lib,
  pkgs,
  nixclyx,
  ...
}:
let
  cfg = config.psyclyx.nixos.derived.pxe;
  eg = config.psyclyx.egregore;
  enabled = cfg.serve;

  hostname = config.psyclyx.nixos.host or null;
  myEnt = if hostname == null then null else eg.entities.${hostname} or null;
  # Resolved address view (folds in gateway-derived addresses), so this
  # works whether the PXE server is the gateway of the network or just
  # an L2 listener on it.
  myAddrs = if myEnt == null then { } else myEnt.addresses or { };

  # Address the PXE server should advertise as next-server to clients
  # PXE-booting on this network. Null if the PXE server has no IPv4
  # there — in that case the projection skips the reservation rather
  # than serving cross-VLAN.
  nextServerForNetwork = network: (myAddrs.${network} or { }).ipv4 or null;

  pxeHosts = lib.filterAttrs (
    _: e: e.host != null && (e.boot.mode or "local") == "pxe"
  ) eg.entities;

  # MAC for a particular PXE-eligible interface of a host:
  # host.interfaces.<network>.device → host.mac.<device>. VLAN sub-ifaces
  # (e.g. enp1s0.10) inherit the parent's MAC, so strip the dotted
  # suffix as a fallback.
  hostMacOnInterface =
    hostEnt: ifName:
    let
      iface = hostEnt.host.interfaces.${ifName} or null;
      dev = if iface != null then iface.device else null;
      parentDev =
        if dev == null then null else builtins.head (lib.splitString "." dev);
    in
    if dev == null then
      null
    else if hostEnt.host.mac ? ${dev} then
      hostEnt.host.mac.${dev}
    else if parentDev != null && hostEnt.host.mac ? ${parentDev} then
      hostEnt.host.mac.${parentDev}
    else
      null;

  hostIpOnInterface =
    hostEnt: ifName: (hostEnt.host.addresses.${ifName} or { }).ipv4 or null;

  # The rescue system every PXE-mode host boots. Upstream's
  # netboot-minimal is already a self-contained recovery environment
  # (base profile enables ZFS, installation-device enables sshd with
  # root login) — the only thing it needs from us is the admin key.
  # Built against the host's own pkgs set: same pin, same closure.
  rescueEval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    system = null;
    modules = [
      (pkgs.path + "/nixos/modules/installer/netboot/netboot-minimal.nix")
      {
        networking.hostName = "rescue";
        users.users.root.openssh.authorizedKeys.keys = nixclyx.keys.psyc.openssh;
        system.stateVersion = "25.11";
      }
    ];
  };
  rescue = rescueEval.config.system.build;

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

  # One shared rescue bundle per PXE-mode host. The artifacts are
  # identical everywhere; the per-host entries only carry that host's
  # MACs so the per-MAC chain script can name the machine it boots.
  mkClient =
    name: hostEnt:
    let
      macs = lib.filter (m: m != null) (
        map (ifName: hostMacOnInterface hostEnt ifName) (hostEnt.boot.pxeInterfaces or [ ])
      );
    in
    if macs == [ ] then
      null
    else
      {
        inherit name;
        value = {
          inherit macs;
          kernel = "${rescue.kernel}/bzImage";
          initrd = "${rescue.netbootRamdisk}/initrd";
          cmdline = "init=${rescue.toplevel}/init " + lib.concatStringsSep " " rescueEval.config.boot.kernelParams;
        };
      };

  clientPairs = lib.filter (x: x != null) (lib.mapAttrsToList mkClient pxeHosts);

  clients = builtins.listToAttrs clientPairs;

  # Per-network Kea reservations. Each host enumerates the networks it
  # is willing to PXE on (boot.pxeInterfaces); we emit a reservation in
  # each of those pools, with next-server pointing at the PXE server's
  # IP *on that same network*. Networks where the PXE server has no
  # address are skipped — we don't want firmware doing a cross-VLAN
  # TFTP that depends on the server's L2-listener trick.
  hostNetReservations =
    name: hostEnt:
    lib.filter (r: r != null) (
      map (
        ifName:
        let
          mac = hostMacOnInterface hostEnt ifName;
          ip = hostIpOnInterface hostEnt ifName;
          nextServer = nextServerForNetwork ifName;
        in
        if mac == null || ip == null || nextServer == null then
          null
        else
          {
            network = ifName;
            reservation = {
              "hw-address" = mac;
              "ip-address" = ip;
              hostname = name;
              "next-server" = nextServer;
              "boot-file-name" = "ipxe.efi";
            };
          }
      ) (hostEnt.boot.pxeInterfaces or [ ])
    );

  allReservations = lib.flatten (lib.mapAttrsToList hostNetReservations pxeHosts);

  poolExtraReservations = lib.mapAttrs (_: rs: map (r: r.reservation) rs) (
    lib.groupBy (r: r.network) allReservations
  );

  # PXE-server bind addresses: every IP we used as next-server above.
  bindAddresses = lib.unique (map (r: r.reservation."next-server") allReservations);
in
{
  options.psyclyx.nixos.derived.pxe = {
    serve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set to true on the host that should run the PXE server. The
        projection then reads every PXE-mode host and populates
        services.pxe-server.clients with the shared rescue bundle and
        adds matching Kea reservations. The set of addresses we bind
        on falls out of the per-network reservations.
      '';
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8089;
      description = "HTTP port the PXE server uses (must match pxe-server.httpPort).";
    };
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.pxe-server = lib.mkIf (clients != { }) {
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
