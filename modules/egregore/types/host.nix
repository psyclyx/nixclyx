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
            dhcp = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Address is assigned at runtime by DHCP. ipv4/ipv6 may be
                null at config-eval time; consumers that need a literal
                address must use a runtime mechanism (interface-bound
                binds, DDNS).
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Declared host addresses. Read host.attrs.addresses for the
        resolved view, which extends declared entries with addresses
        derived from networks where this host is the gateway.
      '';
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
            port = lib.mkOption {
              type = lib.types.int;
              default = 51820;
              description = ''
                UDP listen port for hubs. Spokes that don't accept
                inbound connections can leave the default.
              '';
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
    dnsAuthority = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        DNS zones this host can update via TSIG/DDNS. Used both for
        serving authoritative DNS and for ACME DNS-01 challenges. The
        ingress projection picks an issuer for a given cert by finding
        a host with the cert's parent zone in dnsAuthority.
      '';
    };
    publicAcme = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        This host accepts ACME challenges (HTTP-01 / TLS-ALPN-01) at
        its public address for any FQDN that resolves there. Used as
        a fallback when no host has DNS authority for the cert's zone.
        Wildcards always require DNS-01 and ignore this.
      '';
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
    boot = lib.mkOption {
      type = lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.enum [ "local" "pxe" ];
            default = "local";
            description = ''
              How this host boots. local = bootloader on local media,
              managed by the host's NixOS config. pxe = PXE-boot from
              the fleet's PXE server; this host has no bootloader.
            '';
          };
          pxeInterfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Egregore network names this host is willing to PXE from.
              The PXE projection emits a per-MAC reservation in each
              named network's DHCP pool, so firmware boot order can pick
              any of them and still chainload iPXE. Each entry must name
              a declared interface; the host's MAC for that NIC comes
              from host.interfaces.<name>.device → host.mac.<device>.
              Empty for mode = "local".
            '';
          };
          useLoader = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              When true, the PXE projection serves the shared lab-loader
              (system.build.netbootRamdisk) for this host instead of the
              host's own kexec ramdisk. The loader then chains into the
              real system whose closure lives on tank/nix-shared. Only
              meaningful for hosts that *also* have their own colmena
              build (so the projection wouldn't fall back to the loader
              automatically); without this flag, mkClient prefers the
              per-host build.
            '';
          };
        };
      };
      default = {};
      description = "How the host gets its kernel + initrd at power-on.";
    };
    openbao = lib.mkOption {
      type = lib.types.submodule {
        options.ssh = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                role = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Name of an openbao-ssh-cert-role entity (kind =
                    "host") this host's sshd presents a signed cert
                    from. The cert is requested at boot using the
                    host's cert-auth token (host.openbao.cert.role)
                    and the host's FQDN on host.openbao.ssh.network.
                  '';
                };
                network = lib.mkOption {
                  type = lib.types.str;
                  default = "lab";
                  description = ''
                    Network whose zone supplies the CN/principal in
                    the SSH host cert. Read as `attrs.fqdns.<network>`.
                  '';
                };
              };
            }
          );
          default = null;
          description = ''
            SSH host-cert binding. When set, the guest signs its own
            host key on boot from the named SSH cert role; clients
            with the CA's pubkey in known_hosts (@cert-authority)
            verify without per-host TOFU.
          '';
        };
        options.cert = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                role = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Name of the openbao-cert-role entity this host
                    auths under. The host gets a cert with CN equal
                    to the host's natural lab-network FQDN (or whatever
                    network the cert role's PKI role permits), uses it
                    to auth, and inherits that role's policies.
                  '';
                };
                commonName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Override the derived CN. Null = use the host's
                    `attrs.fqdns.<network>` for whatever network the
                    cert role expects.
                  '';
                };
                network = lib.mkOption {
                  type = lib.types.str;
                  default = "lab";
                  description = ''
                    Network whose zone supplies the cert CN when
                    `commonName` is unset. Read as
                    `host.attrs.fqdns.<network>`.
                  '';
                };
              };
            }
          );
          default = null;
          description = ''
            OpenBao cert-auth binding. When set, this host is wired
            into the fleet's OpenBao cert auth flow: hypervisor mints
            a wrapped bootstrap token, guest auths with the resulting
            cert, gets the policies of the named role.
          '';
        };
      };
      default = { };
      description = "OpenBao integration knobs for this host.";
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

      # Resolved addresses view — declared addresses, plus gateway-derived
      # entries for networks where this host is the declared gateway
      # (network.refs.gateway directly or inherited from site.refs.gateway).
      # Declared always wins.
      networkEntities = lib.filterAttrs (_: e: e.type == "network") (top.entities or { });

      gatewayHostFor =
        netName: net:
        let
          netGw = net.refs.gateway or null;
          siteName = net.network.site or null;
          site = if siteName != null then top.entities.${siteName} or null else null;
          siteGw = if site != null then site.refs.gateway or null else null;
        in
        if netGw != null then netGw else siteGw;

      gatewayDerivedAddresses = lib.mapAttrs (_: net: {
        ipv4 = net.attrs.gateway4 or null;
        ipv6 = net.attrs.gateway6 or null;
        dhcp = false;
      }) (lib.filterAttrs (netName: net: gatewayHostFor netName net == name) networkEntities);

      # Resolution order (last write wins under //): gateway-derived
      # addresses provide the floor; declared addresses always win.
      resolvedAddresses = gatewayDerivedAddresses // h.addresses;

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
      addresses = resolvedAddresses;
      fqdn = if siteDomain != null then "${name}.${siteDomain}" else null;
      fqdns = lib.mapAttrs (
        addrKey: _:
        let
          netEnt = top.entities.${addrKey} or null;
          zone = if netEnt != null && netEnt.type == "network" then netEnt.attrs.zoneName or "" else "";
        in
        if zone != "" then "${name}.${zone}" else null
      ) resolvedAddresses;
      site = h.site;
      roles = h.roles;
      sshPort = h.sshPort;
      deployAddress = h.deployAddress;
      hasTpm = h.hardware.tpm;
      hypervisor = entity.refs.hypervisor or null;
      isVm = (entity.refs.hypervisor or null) != null;
      label = builtins.concatStringsSep ", " h.roles;
      resolvedExporters = lib.recursiveUpdate computedExporters h.exporters;
    };

  assertions =
    name: entity: top:
    let
      h = entity.host;
      pxe = h.boot.mode == "pxe";
      ifs = h.boot.pxeInterfaces;
      missing = lib.filter (n: !(h.interfaces ? ${n})) ifs;
      hv = entity.refs.hypervisor or null;
      nixDs = entity.refs.nixDataset or null;
      persistDs = entity.refs.persistDataset or null;
      isDatasetRef = target:
        top.entities ? ${target} && top.entities.${target}.type == "zfs-dataset";
    in
    lib.optional (h.site != null) {
      assertion = top.entities ? ${h.site} && top.entities.${h.site}.type == "site";
      message = "host '${name}' references site '${h.site}' which is not a site entity";
    }
    ++ lib.optional pxe {
      assertion = ifs != [] && missing == [];
      message = "host '${name}' boot.mode = \"pxe\" requires boot.pxeInterfaces to be a non-empty list of declared interface names (missing: ${lib.concatStringsSep ", " missing})";
    }
    ++ lib.optional (hv != null) {
      assertion = top.entities ? ${hv} && top.entities.${hv}.type == "host";
      message = "host '${name}' refs.hypervisor → '${hv}' must be a host entity";
    }
    ++ lib.optional (hv != null) {
      # microvm guests don't go through the PXE projection; they boot
      # off an image microvm.nix builds from this NixOS config.
      assertion = h.boot.mode == "local";
      message = "host '${name}' is a microvm guest (refs.hypervisor=${hv}) and must keep boot.mode = \"local\"";
    }
    ++ lib.optional (nixDs != null) {
      assertion = isDatasetRef nixDs;
      message = "host '${name}' refs.nixDataset → '${nixDs}' must be a zfs-dataset entity";
    }
    ++ lib.optional (persistDs != null) {
      assertion = isDatasetRef persistDs;
      message = "host '${name}' refs.persistDataset → '${persistDs}' must be a zfs-dataset entity";
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
