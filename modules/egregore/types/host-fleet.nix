# Fleet host extension — the host blocks that are fleet conventions
# rather than intrinsic to the noun: routing roles (gateway, firewall,
# bgp, kerberos), trust/identity (wireguard, openbao, tpm), DNS
# authority, monitoring targets, and boot intent. The intrinsic noun
# (placement + attachment) is lib/egregore/modules/types/host.nix;
# these fields are added by name via `extends`.
{
  egregoreType = { lib, ... }: {
    extends = "host";

    options = {
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
      dnsAuthority = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Intrinsic DNS zones this host can update via TSIG/DDNS — zones
          the host owns as part of its identity in the fleet. Projections
          union this with apex zones contributed by services that target
          this host via `refs.dnsAuthority` (seen here as
          `entity.refsIn.dnsAuthority`).
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
            firmwareNics = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  adapter = lib.mkOption {
                    type = lib.types.str;
                    description = ''
                      Firmware's name for the card this NIC lives on, as the
                      BMC reports it (e.g. "EmbNic", "FlexLom1", "PciSlot2").
                    '';
                  };
                  port = lib.mkOption {
                    type = lib.types.int;
                    description = "1-based port number on that adapter.";
                  };
                };
              });
              default = {};
              description = ''
                Physical seat of each interface, keyed by egregore network
                name — where the NIC actually is in the chassis.

                This is what lets `pxeInterfaces` be enforced in firmware
                rather than merely hoped for. DHCP reservations decide which
                NICs get *offered* a bootfile, but firmware decides which
                NICs *try* to boot; a NIC that PXEs without a bootfile offer
                stalls forever. Declaring seats lets the BMC projection
                disable network boot on every seat not in pxeInterfaces.

                Seats, not firmware indices: indices (NicBoot1..N) are a
                BIOS enumeration artefact that shifts when cards move, and
                the BMC can resolve seat → index itself. Seats are also
                stable while the host is powered off or wedged in POST,
                which is when you most need to change boot order.
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
            initrdVlans = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Network entity names whose gateway addresses come up
                in initrd (for early SSH unlock, etc.).
              '';
            };
          };
        };
        default = { };
        description = ''
          Fleet-side gateway declaration: which routed segments this
          host brings up in initrd. The routing mechanism itself
          (interfaces, DHCP, QoS) is host config
          (psyclyx.nixos.network.gateway.*); the set of segments the
          host routes is the graph (network.refs.gateway).
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
        isServer = builtins.elem "server" (entity.tags or [ ]);

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
        hasTpm = h.hardware.tpm;
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
      lib.optional pxe {
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
  };
}
