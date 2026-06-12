# Entity type: host (a machine with network addresses).
{
  egregoreType = { lib, ... }: {
    name = "host";
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
          Intrinsic DNS zones this host can update via TSIG/DDNS — zones
          the host owns as part of its identity in the fleet. Projections
          union this with apex zones contributed by services that target
          this host via `refs.dnsAuthority` (seen here as
          `entity.attrs.refsIn.dnsAuthority`).
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
      publicNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Label names this host is reachable as in the public-domain
          zone (`globals.domains.public`), each mapping to an A/AAAA
          record pointing at the host's public address. e.g.
          `publicNames = ["tleilax" "vpn"]` registers
          `tleilax.psyclyx.xyz` + `vpn.psyclyx.xyz`.

          Records are emitted by the public-names projection on the
          host that owns the public zone (via `dnsAuthority`).
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

      gateway = lib.mkOption {
        type = lib.types.submodule {
          options = {
            lanInterface = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Physical LAN trunk interface. Setting this enables the
                gateway projection on this host. Null = not a gateway.
              '';
            };
            wanInterface = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Physical WAN-side interface (trunk parent for transitVlan).";
            };
            lanAddress = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Static address on the untagged LAN trunk parent. Used
                for legacy/setup-VLAN-1 subnets that aren't modeled as
                network entities.
              '';
            };
            initrdVlans = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = ''
                Network entity names whose gateway addresses come up
                in initrd (for early SSH unlock, etc.).
              '';
            };
            initrdKernelModules = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "8021q" ];
              description = "Kernel modules pulled into initrd for early VLAN bringup.";
            };
            transitDhcpV6 = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  duidRawData = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "DHCPv6 client DUID (raw colon-separated hex bytes).";
                  };
                  iaid = lib.mkOption {
                    type = lib.types.int;
                    default = 250;
                  };
                  prefixDelegationHint = lib.mkOption {
                    type = lib.types.str;
                    default = "::/60";
                  };
                };
              };
              default = {};
            };
            cakeQos = lib.mkOption {
              type = lib.types.nullOr (lib.types.submodule {
                options = let
                  mkRate = desc: lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        min = lib.mkOption { type = lib.types.int; description = "${desc} min rate (Kbps)."; };
                        base = lib.mkOption { type = lib.types.int; description = "${desc} base rate (Kbps)."; };
                        max = lib.mkOption { type = lib.types.int; description = "${desc} max rate (Kbps)."; };
                      };
                    };
                  };
                in {
                  download = mkRate "Download";
                  upload = mkRate "Upload";
                };
              });
              default = null;
              description = ''
                CAKE traffic shaping on the WAN transit interface
                (autoderived as wanInterface.transitVlan). Null = no
                shaping. Bandwidth rates in Kbps.
              '';
            };
          };
        };
        default = {};
        description = ''
          Gateway/router declaration. Materialized by derived/gateway.nix
          into psyclyx.nixos.network.gateway.*. Setting lanInterface
          enables the projection; leaving it null is the default.
        '';
      };

      firewall = lib.mkOption {
        type = lib.types.submodule {
          options = {
            zones = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options.extraInterfaces = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = ''
                    Extra device names to assign to this zone, beyond
                    whatever the projection derives from network.zone +
                    host.interfaces. For interfaces that don't map to a
                    network entity — the untagged trunk parent, a WAN
                    VLAN sub-iface, tleilax's mullvad veth, etc.
                  '';
                };
              });
              default = {};
            };
            input = lib.mkOption {
              type = lib.types.attrsOf (lib.types.either
                (lib.types.enum [ "accept" "drop" "reject" ])
                (lib.types.submodule {
                  options = {
                    policy = lib.mkOption {
                      type = lib.types.enum [ "accept" "drop" ];
                      default = "drop";
                    };
                    allowICMP = lib.mkOption { type = lib.types.bool; default = true; };
                    allowedTCPPorts = lib.mkOption { type = lib.types.listOf lib.types.int; default = []; };
                    allowedUDPPorts = lib.mkOption { type = lib.types.listOf lib.types.int; default = []; };
                    rules = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
                  };
                }));
              default = {};
              description = ''
                Per-zone input policy. Each entry is either a bare
                accept/drop/reject (shorthand for `{ policy = ...; }`)
                or a full submodule with port lists and rules.
                Projections to the NixOS firewall normalize both forms.
              '';
            };
            masquerade = lib.mkOption {
              type = lib.types.listOf (lib.types.submodule {
                options = {
                  from = lib.mkOption { type = lib.types.str; };
                  to = lib.mkOption { type = lib.types.str; };
                };
              });
              default = [];
              description = ''
                Zone-to-zone NAT masquerade rules. Empty list = host
                is not a NAT gateway. Materialized into
                psyclyx.nixos.network.firewall.masquerade by the host
                firewall projection.
              '';
            };
          };
        };
        default = {};
        description = ''
          Host-specific firewall declarations. Materialized by
          derived/firewall-host.nix into the
          psyclyx.nixos.network.firewall.* options. Per-host firewall
          configuration lives in the host's egregore entity, not in
          its NixOS module.
        '';
      };

      kerberos = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Force-include this host in the Kerberos principal
                registry (`host/<fqdn>@REALM`). For most hosts the
                projection auto-includes when the host is a consumer
                of an nfs-export with sec != "sys"; flip this to opt
                in for non-NFS uses (kadmin, GSSAPI ssh, etc.) or to
                pre-provision identity ahead of services that need it.
              '';
            };
            fqdnNetwork = lib.mkOption {
              type = lib.types.str;
              default = "vpn";
              description = ''
                Network entity whose FQDN is used in the principal
                (`host/<host.attrs.fqdns.<network>>@REALM`). vpn is
                the default since every host has a VPN address with a
                stable name.
              '';
            };
          };
        };
        default = { };
        description = ''
          Kerberos identity config. The KDC projection (derived/
          kerberos.nix) reads this together with nfs-export data to
          build the realm's principal list.
        '';
      };

      bgp = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            asn = lib.mkOption {
              type = lib.types.int;
              description = "Local BGP ASN for this host.";
            };
            peer = lib.mkOption {
              type = lib.types.str;
              description = ''
                Entity name of the BGP peer (typically a routeros or
                routing-capable host entity). Projections derive the
                peer address from this entity's relevant network.
              '';
            };
            peerAsn = lib.mkOption {
              type = lib.types.int;
              description = "Peer's BGP ASN.";
            };
            uplinkInterface = lib.mkOption {
              type = lib.types.str;
              description = ''
                Interface name on this host carrying the BGP session
                (matches a key in `host.interfaces`). Typically the
                routed transit uplink. The projection emits FRR/bird
                config tied to this interface.
              '';
            };
            uplinkAddress = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                IPv4 address on the uplink interface (CIDR notation).
                Null = BGP-unnumbered (IPv6 link-local discovery).
              '';
            };
            peerUplinkAddress = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Peer's IPv4 address on the shared /30 (no CIDR). Null
                when using BGP-unnumbered.
              '';
            };
          };
        });
        default = null;
        description = ''
          BGP speaker config. When set, derived/bgp.nix emits FRR (or
          equivalent) config for this host to peer with the named
          neighbor over `uplinkInterface`. Announced prefixes come from
          per-host attrs the projection computes (own transit prefix +
          VM /32s when this host hosts microvms with declared
          addresses).
        '';
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
  };
}
