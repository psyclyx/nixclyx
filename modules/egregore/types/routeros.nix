# Entity type: MikroTik RouterOS switch.
{ lib, egregorLib, config, ... }:
let
  portDef = import ../lib/switch-port.nix { inherit lib; };
  portType = portDef.portType;
  portLabel = portDef.portLabel;

  # Hardware port lists for known models.
  modelPorts = {
    "CRS326-24S+2Q+RM" =
      (map (i: "sfp-sfpplus${toString i}") (lib.range 1 24))
      ++ (lib.concatMap (q:
        map (s: "qsfpplus${toString q}-${toString s}") (lib.range 1 4)
      ) (lib.range 1 2));
    "CRS305-1G-4S+IN" =
      ["ether1"] ++ map (i: "sfp-sfpplus${toString i}") (lib.range 1 4);
  };
in
egregorLib.mkType {
  name = "routeros";
  topConfig = config;
  description = "MikroTik RouterOS managed switch.";

  options = {
    model = lib.mkOption { type = lib.types.str; default = ""; };
    identity = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    addresses = lib.mkOption {
      type = lib.types.submodule {
        options.mgmt = lib.mkOption {
          type = lib.types.submodule {
            options.ipv4 = lib.mkOption { type = lib.types.str; default = ""; };
          };
          default = {};
        };
      };
      default = {};
    };
    ports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule portDef.module);
      default = {};
    };
    bonds = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mode = lib.mkOption { type = lib.types.str; default = ""; };
          slaves = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
          lacpMode = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          comment = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      });
      default = {};
    };
  };

  attrs = name: entity: _top: let
    r = entity.routeros;
    active = lib.filterAttrs (_: p: portType p != "unused") r.ports;
  in {
    address = r.addresses.mgmt.ipv4;
    label = "${if r.identity != null then r.identity else name} (${r.model})";
    platform = "routeros";
    model = r.model;
    portCount = builtins.length (builtins.attrNames r.ports);
    activePortCount = builtins.length (builtins.attrNames active);
  };

  verbs = name: entity: top: let
    sw = entity.routeros;
    identity = if sw.identity != null then sw.identity else name;

    mgmt      = top.entities.mgmt;
    mgmtVlan  = mgmt.network.vlan;
    mgmtIp    = sw.addresses.mgmt.ipv4;
    mgmtPLen  = mgmt.attrs.prefixLen;
    mgmtNet   = mgmt.attrs.network4;
    mgmtGw    = mgmt.attrs.gateway4;
    adminKeys = top.conventions.adminSshKeys or [];

    # Port config lookup with default for unassigned hardware ports.
    portCfg = pname: sw.ports.${pname} or {
      vlan = null; vlans = []; meta = { host = null; peer = null; description = null; };
    };

    # Bond slave → bond name lookup.
    bondSlaveMap = lib.foldlAttrs (acc: bondName: bond:
      builtins.foldl' (a: slave: a // { ${slave} = bondName; }) acc bond.slaves
    ) {} sw.bonds;

    bridgeIface = pname:
      if bondSlaveMap ? ${pname} then bondSlaveMap.${pname} else pname;

    hwPorts = modelPorts.${sw.model} or (builtins.attrNames sw.ports);
    activePorts = builtins.filter (n: portType (portCfg n) != "unused") hwPorts;
    bridgeInterfaces = lib.unique (map bridgeIface activePorts);

    # VLAN membership computation.
    accessPorts = builtins.filter (n: portType (portCfg n) == "access") hwPorts;
    trunkPorts  = builtins.filter (n: portType (portCfg n) == "trunk") hwPorts;
    usedVlans = let
      aVlans = map (n: (portCfg n).vlan) accessPorts;
      tVlans = builtins.concatLists (map (n: (portCfg n).vlans) trunkPorts);
    in lib.sort builtins.lessThan (lib.unique (aVlans ++ tVlans ++ [mgmtVlan]));

    accessByVlan = let
      pairs = map (pname: { vlan = (portCfg pname).vlan; port = pname; }) accessPorts;
    in builtins.groupBy (p: toString p.vlan) pairs;

    trunkCarriesVlan = pname: vlan: builtins.elem vlan (portCfg pname).vlans;

    vlanEntry = vlan: let
      vStr = toString vlan;
      untagged = if accessByVlan ? ${vStr}
        then lib.unique (map (p: bridgeIface p.port) accessByVlan.${vStr})
        else [];
      tIfaces = lib.unique (builtins.filter (iface:
        builtins.any (tp: bridgeIface tp == iface && trunkCarriesVlan tp vlan) trunkPorts
      ) (map bridgeIface trunkPorts));
      tagged = tIfaces ++ (if vlan == mgmtVlan then ["bridge1"] else []);
    in {
      vlan_ids = vStr;
      inherit tagged untagged;
    };

    projection = {
      model = sw.model;

      system = {
        inherit identity;
        timezone    = "America/Los_Angeles";
        dns_servers = [mgmtGw];
        ssh = {
          host_key_type = "ed25519";
          keys = map (key: { inherit key; user = "admin"; }) adminKeys;
        };
        snmp = { enabled = true; };
      };

      interfaces = map (pname: {
        name    = pname;
        enabled = true;
      }) activePorts;

      bonds = lib.mapAttrsToList (bondName: bond: {
        name      = bondName;
        mode      = bond.mode;
        slaves    = bond.slaves;
        lacp_mode = bond.lacpMode;
        comment   = bond.comment;
      }) sw.bonds;

      bridge = {
        name            = "bridge1";
        protocol_mode   = "none";
        igmp_snooping   = true;
        vlan_filtering  = true;
        ports = map (iface: let
          portName = if sw.bonds ? ${iface}
            then builtins.head sw.bonds.${iface}.slaves
            else iface;
          p = portCfg portName;
          mode = portType p;
        in {
          interface = iface;
          pvid      = if mode == "access" then p.vlan else 1;
          comment   =
            if sw.bonds ? ${iface} then
              if sw.bonds.${iface}.comment != null then sw.bonds.${iface}.comment else iface
            else portLabel p;
        }) bridgeInterfaces;
        vlans = map vlanEntry usedVlans;
      };

      vlan_interfaces = [{
        interface = "bridge1";
        name      = "vlan${toString mgmtVlan}";
        vlan_id   = mgmtVlan;
      }];

      addresses = [{
        address   = "${mgmtIp}/${toString mgmtPLen}";
        interface = "vlan${toString mgmtVlan}";
        network   = mgmtNet;
      }];

      routes = [{
        disabled = true;
        dst      = "0.0.0.0/0";
        gateway  = mgmtGw;
      }];
    };

    json = builtins.toJSON projection;
    rscName = "${identity}.rsc";
  in {
    config-json = {
      description = "Output the switch configuration as JSON.";
      pure = true;
      impl = json;
    };
    generate-config = {
      description = "Generate complete RouterOS .rsc configuration.";
      impl = ''routeros-config generate <<'EGREGORE_EOF'
${json}
EGREGORE_EOF'';
    };
    deploy = {
      description = "Deploy config to switch (upload + reset-configuration).";
      impl = ''
        echo "Generating ${rscName}..." >&2
        tmpfile=$(mktemp --suffix=.rsc)
        trap "rm -f $tmpfile" EXIT
        routeros-config generate <<'EGREGORE_EOF' > "$tmpfile"
${json}
EGREGORE_EOF

        echo "Uploading to ${mgmtIp} via SCP..." >&2
        scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
          "$tmpfile" "admin@${mgmtIp}:/${rscName}"

        echo "Resetting configuration (switch will reboot)..." >&2
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
          "admin@${mgmtIp}" \
          "/system/reset-configuration no-defaults=yes run-after-reset=${rscName}"

        echo "Deploy complete. Switch will reboot and apply ${rscName}." >&2'';
    };
  };
}
