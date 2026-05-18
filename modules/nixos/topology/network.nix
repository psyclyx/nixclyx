# Egregore → network interfaces projection.
#
# Reads the current host's egregore entity and projects its network
# membership into psyclyx.nixos.network.interfaces options:
#
#   - VLAN netdevs for VLAN-backed interfaces
#   - Static addresses from host.addresses
#   - Policy routing for non-default networks
#   - Initrd interface for the default network
#   - Firewall zone membership
#
# This module is generally applicable to any egregore fleet — it contains
# no site-specific knowledge.  Host configs declare physical topology
# (bonds, bridges) and set defaultNetwork; this module fills in the rest.
{config, lib, ...}: let
  cfg = config.psyclyx.nixos.network.topology;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  me = eg.entities.${hostname}.host or null;
  hasEntity = me != null;
  enabled = cfg.enable && hasEntity;

  # Networks this host participates in (has both interface + address).
  # Excludes mgmt (BMC) and vpn (WireGuard, handled by topology/wireguard.nix).
  hostNetworks = lib.filterAttrs (name: _:
    name != "mgmt"
    && name != "vpn"
    && me.interfaces ? ${name}
    && me.addresses ? ${name}
  ) me.addresses;

  # Determine if an interface device is a VLAN (parent.id pattern matching a network's VLAN).
  mkVlanEntry = netName: _addr: let
    device = me.interfaces.${netName}.device;
    net = eg.entities.${netName};
    vlanId = net.network.vlan;
    expectedSuffix = ".${toString vlanId}";
    isVlan = lib.hasSuffix expectedSuffix device;
    parent = lib.removeSuffix expectedSuffix device;
  in if isVlan then {
    name = device;
    value = { id = vlanId; inherit parent; };
  } else null;

  generatedVlans = builtins.listToAttrs
    (builtins.filter (x: x != null) (lib.mapAttrsToList mkVlanEntry hostNetworks));

  # Generate L3 network entries for all host networks.
  #
  # Address-mode contract (see nixclyx/CLAUDE.md):
  #   - dhcp = true OR ipv4 = null → DHCP=yes on the device. The
  #     declared ipv4 (if any) is informational — the actual lease comes
  #     from the Kea reservation keyed by MAC.
  #   - dhcp = false AND ipv4 set     → static address. Used by hosts
  #     that are the gateway (via topology/gateway.nix), not via this
  #     projection. We still honor the field as a fallback for legacy
  #     entries that haven't been flipped yet.
  mkNetworkEntry = netName: _addr: let
    netEnt = eg.entities.${netName};
    device = me.interfaces.${netName}.device;
    addr = me.addresses.${netName};
    net = netEnt.attrs;
    prefixLen = toString net.prefixLen;
    isDefault = netName == cfg.defaultNetwork;
    mtu = netEnt.network.mtu or 1500;
    useDhcp = (addr.dhcp or false) || (addr.ipv4 or null) == null;
  in {
    name = device;
    value = {
      ipv6AcceptRA = true;
      requiredForOnline = if isDefault then "routable" else "no";
      # Only emit non-default MTU so existing 1500-byte interfaces keep
      # leaving the kernel default.
      mtu = if mtu != 1500 then mtu else null;
    }
    // (if useDhcp then {
      dhcp = true;
    } else {
      addresses =
        ["${addr.ipv4}/${prefixLen}"]
        ++ lib.optional (addr.ipv6 or null != null) "${addr.ipv6}/64";
    })
    // (if isDefault
        # On the default network, static-mode hosts need gateway + DNS
        # set explicitly; DHCP-mode hosts get them from option 3/6.
        then lib.optionalAttrs (!useDhcp) {
          gateway = net.gateway4;
          dns = [net.gateway4];
        }
        # Non-default networks always get policy routing so reply
        # traffic exits via the right interface regardless of address
        # acquisition mode.
        else {
          policyRouting = {
            table = netEnt.network.vlan;
            gateway = net.gateway4;
            subnet = "${net.network4}/${toString net.prefixLen}";
          };
        });
  };

  generatedNetworks = builtins.listToAttrs
    (lib.mapAttrsToList mkNetworkEntry hostNetworks);

  # All interface device names for firewall.
  allDevices = lib.mapAttrsToList (_: _addr: me.interfaces.${_}.device) hostNetworks;

  # Default network's interface for initrd.
  defaultDevice =
    if hostNetworks ? ${cfg.defaultNetwork}
    then me.interfaces.${cfg.defaultNetwork}.device
    else null;
in {
  options.psyclyx.nixos.network.topology = {
    enable = lib.mkEnableOption "project egregore host data into network interfaces";
    defaultNetwork = lib.mkOption {
      type = lib.types.str;
      description = "Egregore network name that gets the default route (others get policy routing).";
    };
  };

  config = lib.mkIf enabled {
    psyclyx.nixos.network.interfaces = {
      vlans = generatedVlans;
      networks = generatedNetworks;
      initrd.interfaces = lib.optional (defaultDevice != null) defaultDevice;
    };

    psyclyx.nixos.network.firewall.zones.lan.interfaces = allDevices ++ ["wg0"];
  };
}
