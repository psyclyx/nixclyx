# NFS server — declarative wrapper over nixpkgs' services.nfs.server.
#
# Takes a list of exports with consumer ACLs as data. Knows nothing about
# any specific fleet; the projection at topology/nfs.nix is what reads
# nfs-export entities and sets the `exports` option here.
{
  path = ["psyclyx" "nixos" "services" "nfs-server"];
  description = "NFS v4 server with declarative export ACLs";

  options = {lib, ...}: {
    exports = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Local path to export.";
            };
            clients = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    address = lib.mkOption {
                      type = lib.types.str;
                      description = "Client IP / CIDR / hostname.";
                    };
                    readOnly = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                    };
                    options = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [
                        "sync"
                        "no_subtree_check"
                        "no_root_squash"
                      ];
                      description = ''
                        Per-client export options. Adjust if a particular
                        client should be root-squashed or have different
                        write semantics.
                      '';
                    };
                  };
                }
              );
              default = [];
            };
            fsid = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = ''
                Explicit fsid for the export. Useful when exporting a
                filesystem that crosses ZFS dataset boundaries — clients
                won't traverse mountpoints without fsid stability.
              '';
            };
          };
        }
      );
      default = [];
      description = "Declarative NFS exports. Empty disables the server.";
    };

    bindAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        IP addresses for the NFS server to bind. Empty = all. Set
        explicitly to keep NFS off other interfaces.
      '';
    };
  };

  config = {cfg, lib, ...}: let
    formatClient = client: let
      optsStr = lib.concatStringsSep ","
        ((if client.readOnly then ["ro"] else ["rw"]) ++ client.options);
    in "${client.address}(${optsStr})";

    formatExport = exp: let
      clientStr = lib.concatMapStringsSep " " formatClient exp.clients;
      fsidStr = lib.optionalString (exp.fsid != null)
        " # fsid=${toString exp.fsid}";
    in "${exp.path} ${clientStr}${fsidStr}";

    exportsFile = lib.concatMapStringsSep "\n" formatExport cfg.exports;
  in lib.mkIf (cfg.exports != []) {
    services.nfs.server = {
      enable = true;
      exports = exportsFile;
    }
    // lib.optionalAttrs (cfg.bindAddresses != []) {
      hostName = lib.head cfg.bindAddresses;
    };

    psyclyx.nixos.network.ports.nfs = {
      tcp = [ 2049 ];
      udp = [ 2049 ];
    };
  };
}
