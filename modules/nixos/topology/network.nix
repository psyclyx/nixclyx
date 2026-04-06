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
  mkNetworkEntry = netName: _addr: let
    device = me.interfaces.${netName}.device;
    addr = me.addresses.${netName};
    net = eg.entities.${netName}.attrs;
    prefixLen = toString net.prefixLen;
    isDefault = netName == cfg.defaultNetwork;
  in {
    name = device;
    value = {
      addresses =
        ["${addr.ipv4}/${prefixLen}"]
        ++ lib.optional (addr.ipv6 or null != null) "${addr.ipv6}/64";
      ipv6AcceptRA = true;
      requiredForOnline = if isDefault then "routable" else "no";
    }
    // (if isDefault then {
      gateway = net.gateway4;
      dns = [net.gateway4];
    } else {
      policyRouting = {
        table = eg.entities.${netName}.network.vlan;
        gateway = net.gateway4;
        subnet = "${net.prefix}/${toString net.prefixLen}";
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
