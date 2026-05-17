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
    bindAddress = lib.mkOption {
      type = lib.types.str;
      description = "IPv4 address the TFTP + HTTP servers bind. Reachable from clients.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8089;
    };

    clients = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mac = lib.mkOption {
              type = lib.types.str;
              description = "PXE client's MAC (any case, colon-separated).";
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

    # iPXE script served per-MAC. The chainload protocol: iPXE pulls
    # this file via HTTP, executes it, and the script tells it which
    # kernel + initrd to load.
    mkIpxeScript = name: client: ''
      #!ipxe
      echo Booting ${name}...
      kernel http://${cfg.bindAddress}:${toString cfg.httpPort}/boot/${name}/kernel ${client.cmdline}
      initrd http://${cfg.bindAddress}:${toString cfg.httpPort}/boot/${name}/initrd
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
        cat > $out/http/boot/${macKey client.mac}.ipxe <<'EOF'
        ${mkIpxeScript name client}
        EOF
      '') cfg.clients
    ));
  in lib.mkIf (cfg.clients != {}) {
    # TFTP: serve the iPXE binaries. atftpd is the standard small TFTP
    # daemon in nixpkgs.
    services.atftpd = {
      enable = true;
      root = "${bundle}/tftp";
    };

    # HTTP: nginx serves the per-host directories and the per-MAC iPXE
    # scripts. Both on the bind address only — no need to expose this
    # widely.
    services.nginx = {
      enable = true;
      virtualHosts."pxe" = {
        listen = [{
          addr = cfg.bindAddress;
          port = cfg.httpPort;
        }];
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
