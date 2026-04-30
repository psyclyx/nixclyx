# Entity type: host (a machine with network addresses).
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "host";
  topConfig = config;
  description = "A machine with network addresses and hardware facts.";

  options = {
    addresses = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            ipv4 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            ipv6 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        }
      );
      default = { };
    };
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.device = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        }
      );
      default = { };
    };
    mac = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
    };
    wireguard = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            publicKey = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            endpoint = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            exportedRoutes = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            allowedNetworks = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
        }
      );
      default = null;
    };
    site = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Site entity name where this host lives.";
    };
    roles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    sshPort = lib.mkOption {
      type = lib.types.int;
      default = 22;
    };
    deployAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH target for deployment. Null = not remotely deployable.";
    };
    deployUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "SSH user for deployment.";
    };
    publicIPv4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    publicIPv6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    hardware = lib.mkOption {
      type = lib.types.submodule {
        options.tpm = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
      default = { };
    };
    exporters = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.int;
              default = 0;
            };
            networks = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
        }
      );
      default = { };
    };
  };

  attrs =
    name: entity: top:
    let
      h = entity.host;
      vpn = h.addresses.vpn or null;
      siteEntity = if h.site != null then top.entities.${h.site} or null else null;
      siteDomain = if siteEntity != null then siteEntity.site.domain or null else null;

      isServer = builtins.elem "server" (h.roles or [ ]);

      myGroups = lib.filterAttrs (
        _: g: g.type == "ha-group" && builtins.elem name g.ha-group.members
      ) top.entities;
      hasService = svc: builtins.any (g: g.ha-group.services ? ${svc}) (builtins.attrValues myGroups);

      computedExporters =
        (lib.optionalAttrs isServer {
          node = {
            port = 9100;
            networks = [ "vpn" ];
          };
          smartctl = {
            port = 9633;
            networks = [ "vpn" ];
          };
        })
        // (lib.optionalAttrs (hasService "postgresql") {
          postgres = {
            port = 9187;
            networks = [ "infra" ];
          };
          patroni = {
            port = 8008;
            networks = [ "infra" ];
          };
        })
        // (lib.optionalAttrs (hasService "redis") {
          redis = {
            port = 9121;
            networks = [ "infra" ];
          };
        })
        // (lib.optionalAttrs (hasService "s3") {
          seaweedfs-volume = {
            port = 9328;
            networks = [ "infra" ];
          };
          seaweedfs-filer = {
            port = 9329;
            networks = [ "infra" ];
          };
          seaweedfs-s3 = {
            port = 9330;
            networks = [ "infra" ];
          };
        })
        // (lib.optionalAttrs (hasService "openbao") {
          openbao = {
            port = 8200;
            networks = [ "infra" ];
          };
        });
    in
    {
      address = if vpn != null then vpn.ipv4 else null;
      fqdn = if siteDomain != null then "${name}.${siteDomain}" else null;
      site = h.site;
      roles = h.roles;
      sshPort = h.sshPort;
      deployAddress = h.deployAddress;
      hasTpm = h.hardware.tpm;
      label = builtins.concatStringsSep ", " h.roles;
      resolvedExporters = lib.recursiveUpdate computedExporters h.exporters;
    };

  assertions =
    name: entity: top:
    let
      h = entity.host;
    in
    lib.optional (h.site != null) {
      assertion = top.entities ? ${h.site} && top.entities.${h.site}.type == "site";
      message = "host '${name}' references site '${h.site}' which is not a site entity";
    };

  verbs =
    name: entity: _top:
    let
      h = entity.host;
      target = h.deployAddress;
      portFlag = lib.optionalString (h.sshPort != 22) "-p ${toString h.sshPort} ";
      sshOpts = lib.optionalString (h.sshPort != 22) "-o Port=${toString h.sshPort} ";
      sshDest = "${h.deployUser}@${target}";
    in
    lib.optionalAttrs (target != null) {
      deploy = {
        description = "Build, copy, and switch. Pass nix-build args (e.g. ./default.nix -A hosts.${name}).";
        impl = ''
          if [[ $# -eq 0 ]]; then
            echo "Usage: egregore verb ${name} deploy <nix-build args...>" >&2
            echo "" >&2
            echo "Examples:" >&2
            echo "  egregore verb ${name} deploy ./default.nix -A hosts.${name}" >&2
            echo "  egregore verb ${name} deploy /nix/store/...-nixos-system" >&2
            exit 1
          fi

          # If the argument is already a store path, use it directly.
          if [[ "$1" == /nix/store/* && -e "$1" ]]; then
            result="$1"
            echo "Using pre-built closure: $result"
          else
            echo "Building ${name}..."
            result=$(nix-build "$@" --no-out-link)
          fi

          echo "Copying closure to ${target}..."
          NIX_SSHOPTS="${sshOpts}" nix-copy-closure --to ${sshDest} "$result"
          echo "Switching..."
          ssh ${portFlag}${sshDest} "$result/bin/switch-to-configuration switch"
          echo "Deployed ${name}."
        '';
      };
    };
}
