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

  # Look up a PXE host's MAC: host.interfaces.<pxeInterface>.device,
  # then host.mac.<device>.
  hostPxeMac = name: hostEnt: let
    h = hostEnt.host;
    ifName = h.boot.pxeInterface;
    iface = h.interfaces.${ifName} or null;
    dev = if iface != null then iface.device else null;
  in
    if dev != null && (h.mac ? ${dev}) then h.mac.${dev}
    else null;

  hostPxeNetwork = hostEnt: hostEnt.host.boot.pxeInterface;

  hostPxeIp = name: hostEnt: let
    netName = hostPxeNetwork hostEnt;
    addr = hostEnt.host.addresses.${netName} or null;
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
    mac = hostPxeMac name hostEnt;
    nodeCfg = nodes.${name}.config or null;
    hasBuild =
      nodeCfg != null
      && nodeCfg ? system
      && nodeCfg.system ? build
      && nodeCfg.system.build ? netbootRamdisk;
  in
    if mac != null && hasBuild
    then {
      inherit name;
      value = {
        inherit mac;
        kernel = "${nodeCfg.system.build.kernel}/bzImage";
        initrd = "${nodeCfg.system.build.netbootRamdisk}/initrd";
        cmdline = lib.concatStringsSep " " nodeCfg.boot.kernelParams;
      };
    }
    else null;

  clientPairs = lib.filter (x: x != null)
    (lib.mapAttrsToList mkClient pxeHosts);

  clients = builtins.listToAttrs clientPairs;

  # Per-network Kea reservations. Each PXE host's pxeInterface picks
  # which DHCP pool to attach the reservation to. Group by network so
  # we can push one extraReservations list per pool.
  mkReservation = name: hostEnt: {
    "hw-address" = hostPxeMac name hostEnt;
    "ip-address" = hostPxeIp name hostEnt;
    hostname = name;
    "next-server" = cfg.bindAddress;
    "boot-file-name" = "ipxe.efi";
  };

  pxeHostList = lib.attrValues
    (lib.filterAttrs (n: e:
      hostPxeMac n e != null && hostPxeIp n e != null
    ) (lib.mapAttrs (n: e: e) pxeHosts));

  reservationsByNetwork = lib.groupBy hostPxeNetwork pxeHostList;

  poolExtraReservations = lib.mapAttrs (_netName: hosts:
    map (e:
      let
        # Find the entity name for this host (groupBy lost it).
        names = lib.attrNames (lib.filterAttrs (_: x: x == e) pxeHosts);
      in
      mkReservation (lib.head names) e
    ) hosts
  ) reservationsByNetwork;
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
