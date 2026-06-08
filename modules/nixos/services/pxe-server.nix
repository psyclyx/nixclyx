# PXE server — TFTP for the iPXE chainload binary + HTTP for per-host
# netboot bundles.
#
# Layout served:
#   tftp:/ipxe.efi        — UEFI chainload (iPXE built from upstream)
#   tftp:/undionly.kpxe   — BIOS chainload (also iPXE)
#   http://$host/boot/$mac.ipxe       — per-MAC iPXE script
#   http://$host/boot/$client/kernel  — per-host kernel image
#   http://$host/boot/$client/initrd  — per-host initramfs
#
# Clients are declared as data (no upstream config). The PXE projection
# at topology/pxe.nix is what populates `clients` from egregore hosts
# whose boot.mode == "pxe".
{
  path = ["psyclyx" "nixos" "services" "pxe-server"];
  description = "TFTP + HTTP for iPXE chainload and per-host netboot bundles";

  options = {lib, ...}: {
    bindAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        IPv4 addresses to serve PXE on. One TFTP daemon + one nginx
        listener is bound per address. Each entry should be the PXE
        server's IP on a subnet whose clients PXE-boot — so reply
        traffic is sourced from the address the client originally
        contacted, avoiding multi-homed asymmetric-routing issues
        with PXE firmware.
      '';
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8089;
    };

    clients = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            macs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = ''
                MACs that should chainload this client's boot bundle.
                One iPXE script gets emitted per MAC so the host can
                PXE-boot from any of its NICs.
              '';
            };
            kernel = lib.mkOption {
              type = lib.types.path;
              description = "Linux kernel image (bzImage) to serve.";
            };
            initrd = lib.mkOption {
              type = lib.types.path;
              description = "Initramfs image to serve (typically a netbootRamdisk).";
            };
            cmdline = lib.mkOption {
              type = lib.types.str;
              default = "init=/nix/var/nix/profiles/system/init";
              description = "Kernel cmdline passed in the iPXE chain script.";
            };
          };
        }
      );
      default = {};
    };

    ipxeBinaries = lib.mkOption {
      type = lib.types.submodule {
        options = {
          uefi = lib.mkOption {
            type = lib.types.path;
            description = "ipxe.efi for UEFI clients.";
          };
          bios = lib.mkOption {
            type = lib.types.path;
            description = "undionly.kpxe for BIOS clients.";
          };
        };
      };
      description = ''
        iPXE chainload binaries. Caller (typically the projection) sources
        these from pkgs.ipxe.
      '';
    };

  };

  config = {cfg, lib, pkgs, ...}: let
    macKey = mac: lib.toLower (lib.replaceStrings [":"] ["-"] mac);

    # iPXE script served per-MAC. The kernel/initrd URLs use iPXE's
    # ''${next-server} variable so they target whichever address the
    # client first reached us at — keeping all of TFTP, HTTP-chain,
    # and HTTP-fetch on a single subnet. Kea hands out per-network
    # next-server values via the projection.
    mkIpxeScript = name: client: ''
      #!ipxe
      echo Booting ${name}...
      kernel http://''${next-server}:${toString cfg.httpPort}/boot/${name}/kernel ${client.cmdline}
      initrd http://''${next-server}:${toString cfg.httpPort}/boot/${name}/initrd
      boot
    '';

    # Drop the bundle into a deterministic store directory. Each client
    # gets a stable URL (path) the server can read at request time.
    bundle = pkgs.runCommand "pxe-bundles" { } (''
      mkdir -p $out/tftp
      ln -s ${cfg.ipxeBinaries.uefi} $out/tftp/ipxe.efi
      ln -s ${cfg.ipxeBinaries.bios} $out/tftp/undionly.kpxe

      mkdir -p $out/http/boot
    '' + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: client: ''
        mkdir -p $out/http/boot/${name}
        ln -s ${client.kernel} $out/http/boot/${name}/kernel
        ln -s ${client.initrd} $out/http/boot/${name}/initrd
      '' + lib.concatMapStringsSep "\n" (mac: ''
        cat > $out/http/boot/${macKey mac}.ipxe <<'EOF'
        ${mkIpxeScript name client}
        EOF
      '') client.macs) cfg.clients
    ));
  in lib.mkIf (cfg.clients != {} && cfg.bindAddresses != []) {
    assertions = [{
      assertion = cfg.bindAddresses != [];
      message = "pxe-server has clients but no bindAddresses";
    }];

    # TFTP: one atftpd instance per bind address. atftpd's --bind-address
    # is single-valued, and a 0.0.0.0 bind on a multi-homed host has
    # asymmetric-routing problems (the data-socket reply source IP gets
    # picked by route, not by inbound destination, which PXE firmware
    # rejects with ICMP unreachable).
    systemd.services = lib.listToAttrs (map (addr: let
      key = lib.replaceStrings ["."] ["-"] addr;
    in lib.nameValuePair "atftpd-${key}" {
      description = "atftpd TFTP server (${addr})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.atftp}/sbin/atftpd --daemon --no-fork --user nobody --group nogroup --bind-address ${addr} ${bundle}/tftp";
        Restart = "always";
      };
    }) cfg.bindAddresses);

    # HTTP: nginx serves the per-host directories and the per-MAC iPXE
    # scripts. Bound on each PXE address explicitly so chain/HTTP traffic
    # stays on the same subnet as the originating TFTP.
    services.nginx = {
      enable = true;
      virtualHosts."pxe" = {
        listen = map (addr: { inherit addr; port = cfg.httpPort; }) cfg.bindAddresses;
        locations."/boot/" = {
          alias = "${bundle}/http/boot/";
          extraConfig = "autoindex off;";
        };
      };
    };

    psyclyx.nixos.network.ports.pxe = {
      tcp = [ cfg.httpPort ];
      udp = [ 69 ];  # TFTP
    };
  };
}
