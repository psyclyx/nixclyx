# Entity type: host — a machine with network addresses.
#
# The intrinsic noun: where a host sits (site), what addresses it holds,
# and the physical facts (interfaces, MACs). Everything else a host can
# be — gateway, firewall, trust/identity, monitoring targets, boot
# intent — is a fleet convention and lives in the host-fleet extension
# (modules/egregore/types/host-fleet.nix).
{
  egregoreType = { lib, ... }: {
    name = "host";
    description = "A machine with network addresses and attachment to sites/networks.";

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
          Declared host addresses. The derived `addresses` aspect is the
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
      site = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Site entity name where this host lives.";
      };
    };

    deriveOptions = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Primary management address (the vpn address today). Null when
          the host holds no vpn address. Shared capability — declared
          by every kind that derives it; this is the full declaration.
        '';
      };
      addresses = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
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
            };
          };
        });
        default = { };
        description = ''
          Resolved addresses this entity holds, keyed by network name.
          Shared capability (host and the switch kinds derive it); this
          is the full declaration of the entry shape.
        '';
      };
      fqdn = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Site FQDN (<name>.<site domain>). Null when the host has no site.";
      };
      fqdns = lib.mkOption {
        type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
        default = { };
        description = ''
          Per-network FQDNs, keyed by address key (network name). Null
          value for an address key with no zone.
        '';
      };
      deployAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Where a deploy tool reaches this host. Derived, not declared:
          a directly routed public address first, else a stable name
          (the site FQDN, then the vpn FQDN). Null only if the host has
          neither an address nor a site name.
        '';
      };
      hypervisor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Hypervisor host entity name (refs.hypervisor), when this host is a VM.";
      };
      isVm = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this host is a microvm guest (has refs.hypervisor).";
      };
      interfaceNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Logical interface names, so a switch port that says it's cabled
          to one of them can be checked against reality.
        '';
      };
    };

    derive =
      name: entity: top:
      let
        h = entity.host;
        vpn = h.addresses.vpn or null;
        siteEntity = if h.site != null then top.entities.${h.site} or null else null;
        siteDomain = if siteEntity != null then siteEntity.site.domain or null else null;

        # Resolved addresses view — declared addresses, plus gateway-derived
        # entries for networks where this host is the resolved v4 gateway.
        # `refsIn.gateway` is the graph inverse, so it covers a gateway
        # inherited from the site as well as one written literally; filter
        # to networks, since a site also names a gateway. Declared wins.
        gatewayDerivedAddresses = lib.genAttrs
          (lib.filter (n: (top.entities.${n}.network or null) != null)
            (entity.refsIn.gateway or []))
          (netName: let net = top.entities.${netName}; in {
            ipv4 = net.gateway4 or null;
            ipv6 = net.gateway6 or null;
            dhcp = false;
          });

        # Resolution order (last write wins under //): gateway-derived
        # addresses provide the floor; declared addresses always win.
        resolvedAddresses = gatewayDerivedAddresses // h.addresses;

        fqdn = if siteDomain != null then "${name}.${siteDomain}" else null;
        fqdns = lib.mapAttrs (
          addrKey: _:
          let
            netEnt = top.entities.${addrKey} or null;
            zone = if netEnt != null && netEnt.network != null then netEnt.zoneName or "" else "";
          in
          if zone != "" then "${name}.${zone}" else null
        ) resolvedAddresses;
      in
      {
        address = if vpn != null then vpn.ipv4 else null;
        addresses = resolvedAddresses;
        inherit fqdn fqdns;
        # The management ssh listener is the `ssh` exposure (declared
        # in data — model §6): its port and scopes live there, and the
        # session account lives in the client (home-manager's
        # `sshHosts.user`). Nothing ssh-shaped is derived here.
        # `host.site` is the host's site ref (the derived `site` key is
        # gone — it collided with the `site` kind at top level).
        # Where a deploy tool reaches this host. Derived, not declared:
        # a directly routed public address first, else a stable name
        # (the site FQDN, then the vpn FQDN). Null only if the host has
        # neither an address nor a site name.
        deployAddress =
          let
            publicV4 = (resolvedAddresses.public or { }).ipv4 or null;
            vpnV4 = (resolvedAddresses.vpn or { }).ipv4 or null;
            vpnFqdn = fqdns.vpn or null;
          in
            if publicV4 != null then publicV4
            else if fqdn != null then fqdn
            else if vpnFqdn != null then vpnFqdn
            else vpnV4;
        hypervisor = entity.refs.hypervisor or null;
        isVm = (entity.refs.hypervisor or null) != null;
        # Logical interface names, so a switch port that says it's cabled
        # to one of them can be checked against reality.
        interfaceNames = builtins.attrNames h.interfaces;
      };

    assertions =
      name: entity: top:
      let
        h = entity.host;
      in
      lib.optional (h.site != null) {
        assertion = top.entities ? ${h.site} && top.entities.${h.site}.site != null;
        message = "host '${name}' references site '${h.site}' which is not a site entity";
      };
  };
}
