{
  path = ["psyclyx" "nixos" "filesystems" "nfs-root"];
  description = "tmpfs root + NFS /nix /persist (lab-loader kexec target)";

  options = {lib, ...}: {
    ipNetwork = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = ''
        Egregore network name whose host-address becomes the initrd
        kernel `ip=` cmdline. The /nix and /persist NFS mounts
        themselves come from the storage projection (which derives
        them from host.refs.{nixDataset,persistDataset}).
      '';
    };
  };

  config = { cfg, lib, config, ... }: let
    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;
    me = eg.entities.${hostname} or null;
    addr = if me == null then null else me.host.addresses.${cfg.ipNetwork} or null;
    netEnt = eg.entities.${cfg.ipNetwork} or null;
    prefixLen = if netEnt == null then null else netEnt.attrs.prefixLen or null;
    gateway = if netEnt == null then null else netEnt.attrs.gateway4 or null;

    # Kernel ip= cmdline wants a dotted-quad netmask. Lookup table for
    # the prefixes we actually use; throws on unknown so we notice
    # rather than silently producing nonsense.
    netmaskFor = n: let
      masks = {
        "8"  = "255.0.0.0";
        "16" = "255.255.0.0";
        "23" = "255.255.254.0";
        "24" = "255.255.255.0";
        "25" = "255.255.255.128";
        "26" = "255.255.255.192";
        "27" = "255.255.255.224";
        "28" = "255.255.255.240";
        "29" = "255.255.255.248";
        "30" = "255.255.255.252";
      };
    in masks.${toString n}
       or (throw "nfs-root: no netmask mapping for /${toString n} — extend the table.");

    ipParam =
      if addr == null || addr.ipv4 == null || gateway == null || prefixLen == null
      then null
      else "ip=${addr.ipv4}::${gateway}:${netmaskFor prefixLen}:${hostname}::none";
  in {
    assertions = [{
      assertion = ipParam != null;
      message = ''
        nfs-root on '${hostname}' needs:
          - host.addresses.${cfg.ipNetwork}.ipv4 (got: ${toString (addr.ipv4 or null)})
          - network '${cfg.ipNetwork}' entity with gateway4 + prefixLen attrs
        Both come from egregore — declare the host's static address
        on that network and ensure the network entity exists.
      '';
    }];

    # Root tmpfs; the host has no persistent local storage.
    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };

    # The lab-loader kexecs us in; no bootloader to manage.
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;

    # NFS in initrd so the storage projection's neededForBoot /nix
    # and /persist mounts can succeed.
    boot.initrd.kernelModules = [ "nfs" "nfsv4" ];
    boot.initrd.supportedFilesystems = [ "nfs" "nfs4" ];

    # Kernel sets up the IP before initrd runs, so NFS mounts work
    # without needing networkd in initrd. The empty device field lets
    # the kernel pick whichever interface comes up — only one will on
    # a single-NIC host.
    boot.kernelParams = [ ipParam ];

    # Pair the storage projection: it derives the actual NFS mount
    # entries for /nix and /persist from the host's dataset refs.
    psyclyx.nixos.topology.storage.enable = true;
  };
}
