# switch-config.nix — Generate complete, restorable switch configurations.
#
# Pure Nix string interpolation: no pkgs, no derivations.
#
# Usage:
#   let
#     fleet = import ./data/fleet;
#     gen = import ./lib/switch-config.nix lib fleet;
#   in
#     gen.routeros "mdf-agg01"   # -> Complete RouterOS .rsc script
#     gen.routeros "idf-dist01"  # -> CRS305 RouterOS .rsc script
#     gen.swos "mdf-acc01"       # -> SwOS .swb backup file content
#     gen.sodola "mdf-brk01"     # -> { backup = "<hex>"; portMap = "..."; }
#                                #    Convert hex to binary: echo "$hex" | xxd -r -p
#
lib: fleetData:
let
  networks = fleetData.topology.networks;
  hosts = fleetData.topology.hosts;
  devices = fleetData.devices;

  # ── Encoding helpers ────────────────────────────────────────────

  # Power of 2.
  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);

  # Left-pad a string to at least `width` characters with `fill`.
  lpad = width: fill: s:
    let len = builtins.stringLength s;
    in if len >= width then s
       else lpad width fill (fill + s);

  # Integer to hex string with minimum width (no 0x prefix), lowercase.
  toHex = width: n: lpad width "0" (lib.toLower (lib.toHexString n));

  # Printable ASCII (codes 32–126) as a character list for ord() lookups.
  asciiRef = lib.stringToCharacters
    " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

  # Character → integer code point.
  charCode = c:
    let idx = lib.lists.findFirstIndex (x: x == c) null asciiRef;
    in if idx == null then throw "Non-printable ASCII character"
       else idx + 32;

  # Hex-encode a string (each char → 2 hex digits), for SwOS backup format.
  hexEncodeString = s:
    lib.concatStrings (map (c: toHex 2 (charCode c)) (lib.stringToCharacters s));

  # IPv4 string → little-endian 32-bit hex (SwOS format).
  ipToLE32Hex = ip: let
    octets = map lib.toInt (lib.splitString "." ip);
    val = builtins.elemAt octets 0
        + builtins.elemAt octets 1 * 256
        + builtins.elemAt octets 2 * 65536
        + builtins.elemAt octets 3 * 16777216;
  in "0x${toHex 8 val}";

  # IPv4 string → 4 hex bytes (big-endian, for Sodola binary format).
  ipToHexBytes = ip:
    lib.concatStrings (map (o: toHex 2 (lib.toInt o)) (lib.splitString "." ip));

  # Repeat a hex string N times.
  hexRepeat = n: s: lib.concatStrings (builtins.genList (_: s) n);

  # Null-pad a string to exactly N bytes, return as hex.
  nullPadHex = n: s: let
    bytes = hexEncodeString s;
    padLen = n * 2 - builtins.stringLength bytes;
  in bytes + hexRepeat (padLen / 2) "00";

  # BE uint16 as 2 hex bytes.
  u16hex = n: toHex 4 n;

  # BE uint32 as 4 hex bytes.
  u32hex = n: toHex 8 n;

  # Bitmask from a list of bit positions.
  bitmask = positions: builtins.foldl' (acc: pos: acc + pow2 pos) 0 positions;

  # ── Port helpers ────────────────────────────────────────────────

  # Map network name → VLAN ID (used for management VLAN lookup only).
  vlanOf = name: networks.${name}.vlan;

  # Port classification — derived from which fields are present.
  #   { vlan; }  → access (untagged)
  #   { vlans; } → trunk (tagged)
  #   {}         → unused

  # Natural sort for port names: extract trailing digits for numeric comparison.
  portSortKey = name: let
    digits = builtins.match ".*[^0-9]([0-9]+)$" name;
    prefix = builtins.match "(.*[^0-9])[0-9]+$" name;
  in if digits == null then { p = name; n = 0; }
     else { p = builtins.head prefix; n = lib.toInt (builtins.head digits); };

  portSort = a: b: let
    ka = portSortKey a;
    kb = portSortKey b;
  in if ka.p == kb.p then ka.n < kb.n
     else ka.p < kb.p;

  sortPorts = lib.sort portSort;

  # Classify a port.
  portType = port:
    if port ? vlans then "trunk"
    else if port ? vlan then "access"
    else "unused";

  # Port's native/untagged VLAN.
  portVlan = port: port.vlan or null;

  # Describe a port for comments.
  portLabel = port: let
    meta = port.meta or {};
    host = meta.host or null;
    desc = meta.description or null;
    peer = meta.peer or null;
  in
    if host != null && desc != null then "${host} ${desc}"
    else if host != null then host
    else if desc != null then desc
    else if peer != null then "trunk to ${peer}"
    else if portType port == "access" then "access VLAN ${toString port.vlan}"
    else if portType port == "trunk" then "trunk"
    else "unused";

  # Strip prefix from a CIDR (e.g. "10.0.240.0/24" → "10.0.240.0").
  cidrAddr = cidr: builtins.head (lib.splitString "/" cidr);

  # Extract prefix length from CIDR string.
  cidrLen = cidr: lib.toInt (builtins.elemAt (lib.splitString "/" cidr) 1);

  # ── Hardware model port lists ───────────────────────────────────
  # Every physical port on each model, for complete config generation.
  # Ports not in fleet data are treated as unused/disabled.

  modelPorts = {
    "CRS326-24S+2Q+RM" =
      (map (i: "sfp-sfpplus${toString i}") (lib.range 1 24))
      ++ (lib.concatMap (q:
        map (s: "qsfpplus${toString q}-${toString s}") (lib.range 1 4)
      ) (lib.range 1 2));

    "CRS305-1G-4S+IN" =
      ["ether1"] ++ map (i: "sfp-sfpplus${toString i}") (lib.range 1 4);

    "CSS326-24G-2S+RM" =
      (map (i: "ether${toString i}") (lib.range 1 24))
      ++ ["sfp-sfpplus1" "sfp-sfpplus2"];
  };


  # ══════════════════════════════════════════════════════════════════
  # ── RouterOS generator (.rsc script) ─────────────────────────────
  # ══════════════════════════════════════════════════════════════════

  routeros = switchName: let
    sw = devices.${switchName};
    ports = sw.ports;
    bonds = sw.bonds or {};
    identity = sw.identity or switchName;

    # All hardware ports; fleet-assigned + unassigned.
    hwPorts = modelPorts.${sw.model} or (builtins.attrNames ports);
    allPortNames = sortPorts hwPorts;

    # Port config: fleet data or implicit unused.
    portCfg = name: ports.${name} or { type = "unused"; };

    # ── Bond handling ──
    # Map slave port → bond name.
    bondSlaveMap = lib.foldlAttrs (acc: bondName: bond:
      builtins.foldl' (a: slave: a // { ${slave} = bondName; }) acc bond.slaves
    ) {} bonds;
    isBondSlave = name: bondSlaveMap ? ${name};

    # The bridge-level interface for a port: bond name if it's a slave, else the port itself.
    bridgeIface = name:
      if bondSlaveMap ? ${name} then bondSlaveMap.${name} else name;

    accessPorts  = builtins.filter (n: portType (portCfg n) == "access") allPortNames;
    trunkPorts   = builtins.filter (n: portType (portCfg n) == "trunk") allPortNames;
    unusedPorts  = builtins.filter (n: portType (portCfg n) == "unused") allPortNames;
    activePorts  = builtins.filter (n: portType (portCfg n) != "unused") allPortNames;

    # Bridge-level interfaces: deduplicate bond slaves → bond name.
    bridgeInterfaces = lib.unique (map bridgeIface activePorts);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;
    mgmtNet  = cidrAddr networks.mgmt.ipv4;
    mgmtGw   = let parts = lib.splitString "." mgmtNet;
               in "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}.${builtins.elemAt parts 2}.${toString fleetData.topology.conventions.gatewayOffset}";
    mgmtPLen = cidrLen networks.mgmt.ipv4;

    # Group access ports by VLAN.
    accessByVlan = let
      pairs = map (name: {
        vlan = portVlan (portCfg name);
        port = name;
      }) accessPorts;
    in builtins.groupBy (p: toString p.vlan) pairs;

    # VLANs actually used on this switch — union of access VLANs + all trunk VLANs.
    usedVlans = let
      accessVlans = map (n: portVlan (portCfg n)) accessPorts;
      trunkVlans = builtins.concatLists (map (n: (portCfg n).vlans) trunkPorts);
    in lib.sort builtins.lessThan (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    portList = names: builtins.concatStringsSep "," names;

    # ── Script sections ──

    header = ''
      # RouterOS configuration for ${sw.model} (${switchName})
      # Generated from fleet data — do not edit manually.
      #
      # Port map:
      ${lib.concatStringsSep "\n" (map (n: "#   ${n}: ${portLabel (portCfg n)}${
        let p = portCfg n; in
        if portType p == "access" then " (VLAN ${toString (portVlan p)})" else ""
      }") activePorts)}
      #
    '';

    adminKeys = fleetData.topology.conventions.adminSshKeys or [];

    system = ''
      # ── System ──
      /system identity set name="${identity}"
      /system clock set time-zone-name=America/Los_Angeles
      /ip dns set servers=${mgmtGw}
      /ip ssh set host-key-type=ed25519
      /snmp set enabled=yes
    '' + lib.optionalString (adminKeys != []) (''
      # ── SSH keys ──
    '' + lib.concatImapStringsSep "\n" (i: key: ''
      /file add name=admin-key${toString i}.pub contents="${key}"
      /user ssh-keys import public-key-file=admin-key${toString i}.pub user=admin
      :do { /file remove admin-key${toString i}.pub } on-error={}'') adminKeys + "\n");

    bridge = ''
    ''
    + lib.optionalString (bonds != {}) (''

      # ── Bonds ──
      /interface bonding
    '' + lib.concatStringsSep "\n" (lib.mapAttrsToList (name: bond:
      "add name=${name} mode=${bond.mode} slaves=${portList bond.slaves}"
      + lib.optionalString (bond ? lacpMode) " lacp-mode=${bond.lacpMode}"
      + lib.optionalString (bond ? comment) " comment=\"${bond.comment}\""
    ) bonds) + "\n")
    + ''

      # ── Bridge ──
      /interface bridge
      add name=bridge1 protocol-mode=none igmp-snooping=yes
    '';

    bridgePorts = ''
      # ── Bridge ports ──
      /interface bridge port
    '' + lib.concatStringsSep "\n" (map (iface: let
      # For bonds, get config from the first slave port.
      portName = if bonds ? ${iface}
        then builtins.head bonds.${iface}.slaves
        else iface;
      p = portCfg portName;
      mode = portType p;
      pvid = if mode == "access" then toString (portVlan p) else "1";
      comment = if bonds ? ${iface}
        then bonds.${iface}.comment or iface
        else portLabel p;
    in
      "add bridge=bridge1 interface=${iface} pvid=${pvid} comment=\"${comment}\""
    ) bridgeInterfaces) + "\n";

    # Whether a trunk port carries a given VLAN.
    trunkCarriesVlan = portName: vlan:
      builtins.elem vlan (portCfg portName).vlans;

    vlanTable = ''
      # ── VLAN table ──
      /interface bridge vlan
    '' + lib.concatStringsSep "\n" (map (vlan: let
      vlanStr = toString vlan;
      aPorts = if accessByVlan ? ${vlanStr}
               then lib.unique (map (p: bridgeIface p.port) accessByVlan.${vlanStr})
               else [];
      # Only include trunk interfaces that carry this VLAN.
      tIfaces = lib.unique (builtins.filter (iface:
        builtins.any (tp: bridgeIface tp == iface && trunkCarriesVlan tp vlan) trunkPorts
      ) (map bridgeIface trunkPorts));
      tagged = tIfaces ++ (if vlan == mgmtVlan then ["bridge1"] else []);
      untagged = aPorts;
    in
      "add bridge=bridge1 vlan-ids=${vlanStr}"
      + (if tagged != [] then " tagged=${portList tagged}" else "")
      + (if untagged != [] then " untagged=${portList untagged}" else "")
    ) usedVlans) + "\n";

    mgmtInterface = ''
      # ── Management ──
      /interface vlan
      add interface=bridge1 name=vlan${toString mgmtVlan} vlan-id=${toString mgmtVlan}

      /ip address
      add address=${mgmtIp}/${toString mgmtPLen} interface=vlan${toString mgmtVlan} network=${mgmtNet}

      /ip route
      add disabled=yes dst-address=0.0.0.0/0 gateway=${mgmtGw}
    '';

    enableVlanFiltering = ''
      # ── Enable VLAN filtering (must be LAST to avoid lockout) ──
      /interface bridge set bridge1 vlan-filtering=yes
    '';

    disableUnused = if unusedPorts == [] then "" else ''
      # ── Disable unused ports ──
      /interface ethernet
    '' + lib.concatStringsSep "\n" (map (name:
      "set [find default-name=${name}] disabled=yes"
    ) unusedPorts) + "\n";

  in header + system + "\n" + bridge + "\n" + bridgePorts + "\n" + vlanTable
     + "\n" + mgmtInterface + "\n" + disableUnused + "\n" + enableVlanFiltering;


  # ══════════════════════════════════════════════════════════════════
  # ── SwOS generator (.swb backup file) ────────────────────────────
  # ══════════════════════════════════════════════════════════════════

  swos = switchName: let
    sw = devices.${switchName};
    ports = sw.ports;
    identity = sw.identity or switchName;

    totalPorts = 26; # CSS326: 24 ether + 2 SFP+
    allIndices = lib.range 0 (totalPorts - 1);
    allBits = pow2 totalPorts - 1; # 0x03ffffff

    # Port index mapping: ether1=0, ..., ether24=23, sfp-sfpplus1=24, sfp-sfpplus2=25
    portIndex = name:
      if lib.hasPrefix "ether" name then
        (lib.toInt (lib.removePrefix "ether" name)) - 1
      else if name == "sfp-sfpplus1" then 24
      else if name == "sfp-sfpplus2" then 25
      else throw "Unknown CSS326 port: ${name}";

    # Port name from index (inverse).
    portName = idx:
      if idx < 24 then "ether${toString (idx + 1)}"
      else if idx == 24 then "sfp-sfpplus1"
      else "sfp-sfpplus2";

    # Port config for each index.
    cfgAt = idx: let name = portName idx;
      in ports.${name} or {};
    modeAt = idx: portType (cfgAt idx);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;

    # VLANs present on this switch.
    switchVlans = let
      accessVlans = builtins.filter (v: v != null)
        (map (idx: portVlan (cfgAt idx)) allIndices);
      trunkVlans = builtins.concatLists
        (map (idx: (cfgAt idx).vlans or []) allIndices);
    in lib.sort builtins.lessThan
      (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    # Bitmask of ports that are members of a given VLAN.
    vlanMemberBits = vlan:
      bitmask (builtins.filter (idx: let
        mode = modeAt idx;
        p = cfgAt idx;
      in (mode == "access" && portVlan p == vlan)
         || (mode == "trunk" && builtins.elem vlan p.vlans)
      ) allIndices);

    # Enable bitmask: all non-unused ports.
    enableBits = bitmask
      (builtins.filter (idx: modeAt idx != "unused") allIndices);

    # Hex formatting helpers.
    h2 = n: "0x${toHex 2 n}";
    h8 = n: "0x${toHex 8 n}";

    # Per-port arrays (26 elements each), comma-separated.
    mkArray = f: "[${builtins.concatStringsSep "," (map f allIndices)}]";

    # ── vlan.b ──
    vlanEntries = map (vlan:
      "{nm:'',mbr:${h8 (vlanMemberBits vlan)},vid:${h2 vlan},piso:0x00,lrn:0x01,mrr:0x00,igmp:0x00}"
    ) switchVlans;
    vlanSection = "vlan.b:[${builtins.concatStringsSep "," vlanEntries}]";

    # ── lacp.b ──
    lacpSection = "lacp.b:{mode:${mkArray (_: "0x00")},sgrp:${mkArray (_: "0x00")}}";

    # ── .pwd.b ──
    pwdSection = ".pwd.b:{pwd:''}";

    # ── snmp.b ──
    snmpSection = "snmp.b:{en:0x01,com:'${hexEncodeString "public"}',ci:'',loc:''}";

    # ── rstp.b ──
    rstpSection = "rstp.b:{ena:${h8 allBits}}";

    # ── link.b ──
    portNameFor = idx: let
      p = cfgAt idx;
      mode = modeAt idx;
      name = if mode == "unused" then "" else portLabel p;
    in builtins.substring 0 16 name;

    linkSection = "link.b:{"
      + "en:${h8 enableBits}"
      + ",blkp:0x00"
      + ",an:${h8 allBits}"
      + ",dpxc:${h8 allBits}"
      + ",fctc:${h8 allBits}"
      + ",fctr:0x00"
      + ",spdc:${mkArray (_: "0x00")}"
      + ",cm:${mkArray (_: "0x00")}"
      + ",qtyp:${mkArray (_: "0x00")}"
      + ",nm:[${builtins.concatStringsSep "," (map (idx:
          "'${hexEncodeString (portNameFor idx)}'"
        ) allIndices)}]"
      + ",sfpr:${mkArray (idx: if idx >= 24 then "0x01" else "0x00")}"
      + "}";

    # ── fwd.b ──
    fwdMask = idx: allBits - pow2 idx;

    vlanModeAt = idx: let mode = modeAt idx;
      in if mode == "access" then "0x02"
         else if mode == "trunk" then "0x02"
         else "0x00";

    vlanRecvAt = idx: let mode = modeAt idx;
      in if mode == "access" then "0x00"
         else if mode == "trunk" then "0x00"
         else "0x00";

    defaultVidAt = idx: let
      mode = modeAt idx;
      p = cfgAt idx;
    in if mode == "access" then h2 (portVlan p)
       else "0x01";

    fwdSection = "fwd.b:{"
      + builtins.concatStringsSep "," (map (idx:
          "fp${toString (idx + 1)}:${h8 (fwdMask idx)}"
        ) allIndices)
      + ",lck:0x00,lckf:0x00"
      + ",imr:0x00,omr:0x00,mrto:0x01"
      + ",vlan:${mkArray (idx: vlanModeAt idx)}"
      + ",vlni:${mkArray (idx: vlanRecvAt idx)}"
      + ",dvid:${mkArray (idx: defaultVidAt idx)}"
      + ",fvid:0x00"
      + ",srt:${mkArray (_: "0x64")}"
      + ",suni:0x00"
      + ",fmc:${h8 allBits}"
      + ",ir:${mkArray (_: "0x00")}"
      + "}";

    # ── sys.b ──
    sysSection = "sys.b:{"
      + "id:'${hexEncodeString identity}'"
      + ",wdt:0x01"
      + ",dsc:0x01"
      + ",pdsc:${h8 allBits}"
      + ",ivl:0x00"
      + ",alla:0x00"
      + ",allm:0x00"
      + ",avln:${h2 mgmtVlan}"
      + ",allp:${h8 allBits}"
      + ",mgmt:0x01"
      + ",prio:0x8000"
      + ",cost:0x00"
      + ",frmc:0x00"
      + ",poe:0x00"
      + ",igmp:0x00"
      + ",igmq:0x01"
      + ",igfl:0x00"
      + ",igve:0x01"
      + ",ip:${ipToLE32Hex mgmtIp}"
      + ",dtrp:${h8 allBits}"
      + ",ainf:0x01"
      + ",iptp:0x01"
      + "}";

    # ── acl.b, host.b ──
    aclSection = "acl.b:[]";
    hostSection = "host.b:[]";

    # ── Complete backup ──
    backup = builtins.concatStringsSep ","
      [ vlanSection lacpSection pwdSection snmpSection rstpSection
        linkSection fwdSection sysSection aclSection hostSection ];

    # Human-readable port map (for documentation).
    portMap = let
      allNames = sortPorts (builtins.attrNames ports);
    in ''
      # SwOS Port Configuration for ${sw.model} (${switchName})
      # Generated from fleet data — do not edit manually.
      #
      # Management: ${mgmtIp} on VLAN ${toString mgmtVlan}
      #
      # ┌─────────────────┬──────────┬────────┬──────────────────────────────┐
      # │ Port            │ Mode     │ VLAN   │ Description                  │
      # ├─────────────────┼──────────┼────────┼──────────────────────────────┤
    '' + lib.concatStringsSep "\n" (map (name: let
      p = ports.${name};
      mode = portType p;
      vlan = if mode == "access" then toString (portVlan p) else
             if mode == "trunk" then "all" else "-";
      desc = portLabel p;
      namePad = lib.fixedWidthString 15 " " name;
      modePad = lib.fixedWidthString 8 " " mode;
      vlanPad = lib.fixedWidthString 6 " " vlan;
    in
      "# │ ${namePad} │ ${modePad} │ ${vlanPad} │ ${desc}"
    ) allNames) + "\n"
    + ''
      # └─────────────────┴──────────┴────────┴──────────────────────────────┘
    '';

  in {
    inherit backup portMap;
  };


  # ══════════════════════════════════════════════════════════════════
  # ── Sodola generator (binary .bin backup, output as hex string) ─
  # ══════════════════════════════════════════════════════════════════
  #
  # File format: 2665 bytes, magic "#y#y".  Output is a hex string
  # (5330 hex chars).  Convert to binary: echo "$hex" | xxd -r -p
  #
  # Field map (fully reverse-engineered from SL902-SWTGW218AS firmware):
  #   0x0000  Magic / IP / credentials
  #   0x0060  Switch flags (constant)
  #   0x006e  Storm control (36×4B, all off)
  #   0x0130  Port mirror (disabled)
  #   0x0134  Speed/capability advertisement (10×12B, all auto)
  #   0x01c8  Rate limiting (ingress 9×4B + egress 9×4B, all unlimited)
  #   0x024e  Port isolation (9×4B, all-to-all)
  #   0x027c  Unknown per-port (9×4B, constant 0x1000)
  #   0x04be  Management VLAN hint
  #   0x04cc  Native VLAN per port (9×2B)
  #   0x04e4  Port VLAN type (9×1B: 0x00=trunk, 0x02=access)
  #   0x04f0  VLAN sort index (32×2B)
  #   0x0530  VLAN ID table (32×2B)
  #   0x0574  Per-VLAN data (interleaved membership + VID + name)
  #   0x08b4  Port diagonal matrix (constant)
  #   0x0939  Hardware constant + STP config
  #   0x0950  STP per-port (9×10B)
  #   0x09c9  IGMP enable
  #   0x09cf  QoS per-port queue (9×1B)
  #   0x0a4f  Model string

  sodola = switchName: let
    sw = devices.${switchName};
    ports = sw.ports;
    identity = sw.identity or switchName;

    totalPorts = 9;
    allPortIndices = lib.range 0 (totalPorts - 1);  # 0-indexed

    # Port name from 1-indexed number.
    portName = n: "port${toString n}";

    # Port config by 1-indexed port number.
    portCfgN = n: ports.${portName n} or {};
    portModeN = n: portType (portCfgN n);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;
    mgmtMask = let
      plen = cidrLen networks.mgmt.ipv4;
      # Simple /24, /16, /8 mask generation.
      maskBits = n: if n >= 8 then 255 else 256 - pow2 (8 - n);
    in "${toString (maskBits (lib.min plen 8))}.${toString (maskBits (lib.min (lib.max (plen - 8) 0) 8))}.${toString (maskBits (lib.min (lib.max (plen - 16) 0) 8))}.${toString (maskBits (lib.min (lib.max (plen - 24) 0) 8))}";
    mgmtGw = let parts = lib.splitString "." (cidrAddr networks.mgmt.ipv4);
             in "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}.${builtins.elemAt parts 2}.${toString fleetData.topology.conventions.gatewayOffset}";

    # ── VLAN computation ──────────────────────────────────────────

    # VLANs present on this switch.
    switchVlans = let
      accessVlans = builtins.filter (v: v != null)
        (map (n: portVlan (portCfgN (n + 1))) allPortIndices);
      trunkVlans = builtins.concatLists
        (map (n: (portCfgN (n + 1)).vlans or []) allPortIndices);
    in lib.sort builtins.lessThan
      (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    # VLAN ID table: slot 0 unused (0xffff), slot 1 = VLAN 1, slots 2+ = user VLANs.
    userVlans = switchVlans;  # sorted list of VLANs on this switch
    vidTable = [1 1] ++ userVlans
      ++ builtins.genList (_: 65535) (32 - 2 - builtins.length userVlans);

    # Sort index: maps display position to slot index.
    # VLANs in creation order (slot order), then 0xffff padding.
    usedSlots = lib.range 0 (1 + builtins.length userVlans);
    sortIndex = usedSlots
      ++ builtins.genList (_: 65535) (32 - builtins.length usedSlots);

    # ── Per-VLAN membership ───────────────────────────────────────
    #
    # For VLAN V, compute membership bytes b1 (port 9) and b2 (ports 1-8).
    # b2: bit N = port (N+1) is a member (access VLAN match OR trunk carrying V).
    # b1: bit 0 = port 9 is tagged member, bit 1 = port 9 has V as native VLAN.
    #
    # VLAN 1 is special: ports with trunk VLAN "1" (i.e. default trunk ports
    # not carrying other VLANs) are members.  Port 9 native=1 sets b1 bit 1.

    portIsMember = portNum: vlan: let
      p = portCfgN portNum;
      mode = portType p;
    in
      if mode == "access" then portVlan p == vlan
      else if mode == "trunk" then builtins.elem vlan p.vlans
      else false;

    memberB2 = vlan:
      builtins.foldl' builtins.add 0 (map (n:
        if portIsMember (n + 1) vlan then pow2 n else 0
      ) (lib.range 0 7));

    memberB1 = vlan: let
      p9 = portCfgN 9;
      p9mode = portType p9;
      tagged = p9mode == "trunk" && builtins.elem vlan p9.vlans;
      native = p9.nativeVlan or 1;
    in (if tagged then 1 else 0) + (if native == vlan then 2 else 0);

    # ── Per-VLAN block builder ────────────────────────────────────
    # Block at position P (0-indexed from 0x0586):
    #   b0-b3: membership setA for VLAN at slot (P+1)
    #   b4-b7: membership setB for VLAN at slot (P+1) — setA with b7 |= 0x01
    #   b8-b9: VID for slot (P+2)
    #   b10-b25: name for slot (P+2) (16 bytes null-padded)

    vlanAtSlot = slot: builtins.elemAt vidTable slot;

    # Membership hex (8 bytes) for a VLAN.
    memberHex = vlan: let
      b1 = memberB1 vlan;
      b2 = memberB2 vlan;
      setA = "00${toHex 2 b1}${toHex 2 b2}00";
      # setB: mirror setA, OR 0x01 into b7 (last byte).
      setB = "00${toHex 2 b1}${toHex 2 b2}01";
    in setA + setB;

    # Special case: VLAN 1 setB has only the boot bit (observed behavior).
    vlan1MemberHex = let
      b1 = memberB1 1;
      b2 = memberB2 1;
      setA = "00${toHex 2 b1}${toHex 2 b2}00";
      setB = "00000001";
    in setA + setB;

    # VID + name hex (18 bytes) for a slot.
    vidNameHex = slot: let
      vid = vlanAtSlot slot;
      name = "";  # Sodola fleet data doesn't include VLAN names.
    in if vid == 65535
       then hexRepeat 18 "00"
       else u16hex vid + nullPadHex 16 name;

    # Build one 26-byte block at position P.
    blockHex = pos: let
      memSlot = pos + 1;  # membership is for this slot
      vidSlot = pos + 2;  # VID+name is for this slot
      memVlan = if memSlot < builtins.length vidTable
                then vlanAtSlot memSlot else 65535;
      mem = if memVlan == 65535 then hexRepeat 8 "00"
            else if memVlan == 1 then vlan1MemberHex
            else memberHex memVlan;
      vn = if vidSlot < builtins.length vidTable
           then vidNameHex vidSlot
           else hexRepeat 18 "00";
    in mem + vn;

    # All 30 blocks (positions 0-29), covering slots 1-31 membership + slots 2-31 VID.
    allBlocks = lib.concatStrings (map blockHex (lib.range 0 29));

    # ── Assemble the full 2665-byte file ──────────────────────────

    # 0x0000: Magic + IP + credentials (0x00-0x5f)
    sec_header =
      "23792379" + "00"                               # magic + separator
      + ipToHexBytes mgmtIp                            # 0x0005: IP
      + ipToHexBytes mgmtMask                          # 0x0009: mask
      + ipToHexBytes mgmtGw                            # 0x000d: gateway
      + hexRepeat 6 "00"                               # 0x0011: padding
      + nullPadHex 16 "admin"                          # 0x0017: username
      + hexRepeat 5 "00"                               # 0x0027: padding
      # 0x002c: password hash — default "admin" password encoding (32 bytes).
      + "3c6d3e3d383939696a3069616e3331377a2d7c2a7d2d287e7420707274227377"
      + hexRepeat 20 "00";                             # 0x004c-0x005f: padding

    # 0x0060: Switch flags + storm control + zeroes (0x60-0x12f)
    sec_flags =
      "0000020101200801" + "0909"                      # 0x0060: switch flags
      + hexRepeat 4 "00"                               # 0x006a: padding
      + hexRepeat 36 "ffffff00"                        # 0x006e: storm control (all off)
      + hexRepeat 50 "00";                             # 0x00fe: padding

    # 0x0130: Mirror + speed (0x130-0x1af)
    sec_speed =
      "00000000"                                       # 0x0130: mirror (disabled)
      + "06018080"                                     # 0x0134: speed header
      + hexRepeat 10 (hexRepeat 9 "01" + "000000");   # 0x0138: 10 capability blocks

    # 0x01b0: Rate limiting + isolation + unknown (0x1b0-0x29f)
    sec_rate =
      hexRepeat 24 "00"                                # 0x01b0: padding
      + hexRepeat 9 "00fffff0"                         # 0x01c8: ingress (unlimited)
      + hexRepeat 12 "00"                              # 0x01ec: padding
      + hexRepeat 9 "00fffff0"                         # 0x01f8: egress (unlimited)
      + hexRepeat 50 "00"                              # 0x021c: padding
      + hexRepeat 9 "01ff0000"                         # 0x024e: port isolation (all)
      + hexRepeat 10 "00"                              # 0x0272: padding
      + hexRepeat 9 "00001000"                         # 0x027c: unknown per-port
      ;

    # 0x02a0: Big zero gap + native VLAN + port type (0x2a0-0x4ef)
    sec_vlantables = let
      nativeVlanHex = lib.concatStrings (map (n:
        u16hex (let p = portCfgN (n + 1); mode = portType p;
        in if mode == "access" then portVlan p
           else p.nativeVlan or 1)
      ) allPortIndices);
      portTypeHex = lib.concatStrings (map (n:
        if portModeN (n + 1) == "access" then "02" else "00"
      ) allPortIndices);
      sortHex = lib.concatStrings (map u16hex sortIndex);
      vidHex = lib.concatStrings (map u16hex vidTable);
    in
      hexRepeat 540 "00"                               # 0x02a0: big zero gap
      + hexRepeat 2 "00"                               # 0x04bc: pre-native padding
      + u16hex 1                                       # 0x04be: management VLAN hint
      + hexRepeat 12 "00"                              # 0x04c0: padding
      + nativeVlanHex                                  # 0x04cc: native VLANs (9×2B)
      + hexRepeat 6 "00"                               # 0x04de: padding
      + portTypeHex                                    # 0x04e4: port types (9×1B)
      + "000000"                                       # 0x04ed: padding
      + sortHex                                        # 0x04f0: sort index (32×2B)
      + vidHex                                         # 0x0530: VLAN ID table (32×2B)
      ;

    # 0x0570: VLAN data region (0x570-0x893)
    sec_vlandata =
      "ffff"                                           # 0x0570: padding
      + "0000"                                         # 0x0572: padding
      + vidNameHex 1                                   # 0x0574: VLAN 1 VID+name (18B)
      + allBlocks                                      # 0x0586: 30 interleaved blocks
      ;

    # 0x0892: Post-VLAN zeroes + diagonal matrix (0x892-0x90e)
    diagonalMatrix = lib.concatStrings (map (p: let
      row = builtins.genList (b:
        if b == p then "08"
        else if b == p + 2 then "04"
        else "00"
      ) 10;
    in lib.concatStrings row) (lib.range 0 8));

    sec_postVlan =
      hexRepeat 34 "00"                                # 0x0892: padding
      + diagonalMatrix                                 # 0x08b4: 9×10B diagonal
      + "04"                                           # 0x090e: port 9 overflow byte
      ;

    # 0x090f: Zeroes + constants + STP + IGMP + QoS + trailer (0x90f-0xa68)
    sec_tail =
      hexRepeat 42 "00"                                # 0x090f: padding
      + "76adf100"                                     # 0x0939: static constant
      + "00020000000a00000000"                          # 0x093d: pre-STP constants
      + "0001"                                         # 0x0947: STP flags
      + "0000"                                         # 0x0949: padding
      + "8000"                                         # 0x094b: bridge priority 32768
      + "14"                                           # 0x094d: max age 20
      + "02"                                           # 0x094e: hello 2
      + "0f"                                           # 0x094f: forward delay 15
      # 0x0950: STP per-port (9×10B: 4B path cost + 3B reserved + 1B priority + 2B flags)
      + lib.concatStrings (map (_: "00000000" + "000000" + "80" + "0000")
          (lib.range 1 9))
      + hexRepeat 30 "00"                              # 0x09aa: padding
      + "00"                                           # 0x09c8: pre-IGMP
      + "00"                                           # 0x09c9: IGMP (disabled)
      + hexRepeat 5 "00"                               # 0x09ca: padding
      + hexRepeat 9 "01"                               # 0x09cf: QoS queue (all queue 1)
      + hexRepeat 4 "00"                               # 0x09d8: padding
      + "00000300" + "00000200" + "00000400" + "00000100"  # 0x09dc: QoS config
      + hexRepeat 72 "00"                              # 0x09ec: padding
      # 0x0a34: sequential index (7 entries)
      + "0000010000000200000003000000040000000500000006000000"
      + "07"                                           # 7th entry (partial)
      + nullPadHex 16 "SL902-SWTGW218AS"              # 0x0a4f: model string
      + hexRepeat 10 "00"                              # trailing zeros
      ;

    backup = sec_header + sec_flags + sec_speed + sec_rate
           + sec_vlantables + sec_vlandata + sec_postVlan + sec_tail;

    # Human-readable port map.
    portMap = let
      allNames = sortPorts (builtins.attrNames ports);
    in ''
      # Sodola Port Configuration for ${sw.model} (${switchName})
      # Generated from fleet data — do not edit manually.
      #
      # Management: ${mgmtIp} on VLAN ${toString mgmtVlan}
      #
      # ┌───────┬──────────┬────────┬──────────────────────────────────────────┐
      # │ Port  │ Mode     │ VLAN   │ Description                              │
      # ├───────┼──────────┼────────┼──────────────────────────────────────────┤
    '' + lib.concatStringsSep "\n" (map (name: let
      p = ports.${name};
      mode = portType p;
      vlan = if mode == "access" then toString (portVlan p)
             else if mode == "trunk" then
               (if p ? vlans then lib.concatStringsSep "," (map toString p.vlans) else "all")
             else "-";
      desc = portLabel p;
      namePad = lib.fixedWidthString 5 " " name;
      modePad = lib.fixedWidthString 8 " " mode;
      vlanPad = lib.fixedWidthString 6 " " vlan;
    in
      "# │ ${namePad} │ ${modePad} │ ${vlanPad} │ ${desc}"
    ) allNames) + "\n"
    + ''
      # └───────┴──────────┴────────┴──────────────────────────────────────────┘
    '';

  in {
    inherit backup portMap;
  };


  # ── Enriched port data ──────────────────────────────────────────

  enrichPorts = switchName: let
    sw = devices.${switchName};
  in lib.mapAttrs (portName: port: port // {
    type = portType port;
    vlan = if portType port == "access" then portVlan port else null;
    comment = portLabel port;
  }) sw.ports;

in {
  inherit routeros swos sodola enrichPorts;

  # List all switches of a given platform.
  byPlatform = platform:
    lib.filterAttrs (_: sw: sw.platform == platform) devices;

  # Generate configs for all switches of a platform.
  allRouterOS = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (name: _: routeros name)
      (lib.filterAttrs (_: sw: sw.platform == "routeros") devices)
  );
}
