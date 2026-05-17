# Egregore → PXE projection.
#
# On the host that opts in via `psyclyx.nixos.topology.pxe.serve = true`,
# collect every host entity with boot.mode == "pxe" and populate
# services.pxe-server.clients with that host's MAC + kernel + initrd +
# iPXE script. Cross-host eval pulls in nodes.<labhost>.config.system.build.*
# directly — colmena provides `nodes` as a module arg.
#
# Boot.mode = "local" hosts are ignored. Hosts with mode = "pxe" but
# whose pxeInterface doesn't have a declared MAC on the host are
# skipped with a warning rather than a crash.
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
in {
  options.psyclyx.nixos.topology.pxe = {
    serve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set to true on the host that should run the PXE server. The
        projection then reads every PXE-mode host and populates
        services.pxe-server.clients with their netboot artifacts.
      '';
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address the PXE server binds. Reachable from PXE clients.";
    };
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.services.pxe-server = lib.mkIf (clients != {}) {
      enable = true;
      bindAddress = cfg.bindAddress;
      inherit clients;
      ipxeBinaries = {
        uefi = "${pkgs.ipxe}/ipxe.efi";
        bios = "${pkgs.ipxe}/undionly.kpxe";
      };
    };
  };
}
