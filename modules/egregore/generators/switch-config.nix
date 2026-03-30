# switch-config.nix — Generate complete, restorable switch configurations.
#
# Pure Nix string interpolation: no pkgs, no derivations.
#
# Usage:
#   let
#     egregore = import ./egregore { inherit lib; };
#     fleet = egregore.eval { modules = [...]; };
#     gen = import ./modules/egregore/generators/switch-config.nix lib fleet;
#   in
#     gen.routeros "mdf-agg01"   # -> Complete RouterOS .rsc script
#     gen.swos "mdf-acc01"       # -> SwOS .swb backup file content
#     gen.sodola "mdf-brk01"     # -> { backup = "<hex>"; portMap = "..."; }
#
lib: topConfig:
let
  portDef = import ../lib/switch-port.nix { inherit lib; };

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

  # Map network name → VLAN ID via entity data.
  vlanOf = name: topConfig.entities.${name}.network.vlan;

  portType = portDef.portType;
  portLabel = portDef.portLabel;

  # Port's native/untagged VLAN.
  portVlan = port: port.vlan;

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

  # Strip prefix from a CIDR (e.g. "10.0.240.0/24" → "10.0.240.0").
  cidrAddr = cidr: builtins.head (lib.splitString "/" cidr);

  # Extract prefix length from CIDR string.
  cidrLen = cidr: lib.toInt (builtins.elemAt (lib.splitString "/" cidr) 1);

  # ── Hardware model port lists ───────────────────────────────────

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
    sw = topConfig.entities.${switchName}.routeros;
    ports = sw.ports;
    bonds = sw.bonds;
    identity = if sw.identity != null then sw.identity else switchName;

    # All hardware ports; fleet-assigned + unassigned.
    hwPorts = modelPorts.${sw.model} or (builtins.attrNames ports);
    allPortNames = sortPorts hwPorts;

    # Port config: fleet data or implicit unused.
    portCfg = name: ports.${name} or { vlan = null; vlans = []; meta = { host = null; peer = null; description = null; }; };

    # ── Bond handling ──
    bondSlaveMap = lib.foldlAttrs (acc: bondName: bond:
      builtins.foldl' (a: slave: a // { ${slave} = bondName; }) acc bond.slaves
    ) {} bonds;
    isBondSlave = name: bondSlaveMap ? ${name};

    bridgeIface = name:
      if bondSlaveMap ? ${name} then bondSlaveMap.${name} else name;

    accessPorts  = builtins.filter (n: portType (portCfg n) == "access") allPortNames;
    trunkPorts   = builtins.filter (n: portType (portCfg n) == "trunk") allPortNames;
    unusedPorts  = builtins.filter (n: portType (portCfg n) == "unused") allPortNames;
    activePorts  = builtins.filter (n: portType (portCfg n) != "unused") allPortNames;

    bridgeInterfaces = lib.unique (map bridgeIface activePorts);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;
    mgmtNet  = cidrAddr topConfig.entities.mgmt.network.ipv4;
    mgmtGw   = topConfig.entities.mgmt.attrs.gateway4;
    mgmtPLen = cidrLen topConfig.entities.mgmt.network.ipv4;

    accessByVlan = let
      pairs = map (name: {
        vlan = portVlan (portCfg name);
        port = name;
      }) accessPorts;
    in builtins.groupBy (p: toString p.vlan) pairs;

    usedVlans = let
      accessVlans = map (n: portVlan (portCfg n)) accessPorts;
      trunkVlans = builtins.concatLists (map (n: (portCfg n).vlans) trunkPorts);
    in lib.sort builtins.lessThan (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    portList = names: builtins.concatStringsSep "," names;

    header = ''
      # RouterOS configuration for ${sw.model} (${switchName})
      # Generated from egregore entity data — do not edit manually.
      #
      # Port map:
      ${lib.concatStringsSep "\n" (map (n: "#   ${n}: ${portLabel (portCfg n)}${
        let p = portCfg n; in
        if portType p == "access" then " (VLAN ${toString (portVlan p)})" else ""
      }") activePorts)}
      #
    '';

    adminKeys = topConfig.conventions.adminSshKeys or [];

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
      + lib.optionalString (bond.lacpMode != null) " lacp-mode=${bond.lacpMode}"
      + lib.optionalString (bond.comment != null) " comment=\"${bond.comment}\""
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
      portName = if bonds ? ${iface}
        then builtins.head bonds.${iface}.slaves
        else iface;
      p = portCfg portName;
      mode = portType p;
      pvid = if mode == "access" then toString (portVlan p) else "1";
      comment = if bonds ? ${iface}
        then if bonds.${iface}.comment != null then bonds.${iface}.comment else iface
        else portLabel p;
    in
      "add bridge=bridge1 interface=${iface} pvid=${pvid} comment=\"${comment}\""
    ) bridgeInterfaces) + "\n";

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
    sw = topConfig.entities.${switchName}.swos;
    ports = sw.ports;
    identity = if sw.identity != null then sw.identity else switchName;

    totalPorts = 26;
    allIndices = lib.range 0 (totalPorts - 1);
    allBits = pow2 totalPorts - 1;

    portIndex = name:
      if lib.hasPrefix "ether" name then
        (lib.toInt (lib.removePrefix "ether" name)) - 1
      else if name == "sfp-sfpplus1" then 24
      else if name == "sfp-sfpplus2" then 25
      else throw "Unknown CSS326 port: ${name}";

    portName = idx:
      if idx < 24 then "ether${toString (idx + 1)}"
      else if idx == 24 then "sfp-sfpplus1"
      else "sfp-sfpplus2";

    cfgAt = idx: let name = portName idx;
      in ports.${name} or { vlan = null; vlans = []; meta = { host = null; peer = null; description = null; }; };
    modeAt = idx: portType (cfgAt idx);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;

    switchVlans = let
      accessVlans = builtins.filter (v: v != null)
        (map (idx: portVlan (cfgAt idx)) allIndices);
      trunkVlans = builtins.concatLists
        (map (idx: (cfgAt idx).vlans) allIndices);
    in lib.sort builtins.lessThan
      (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    vlanMemberBits = vlan:
      bitmask (builtins.filter (idx: let
        mode = modeAt idx;
        p = cfgAt idx;
      in (mode == "access" && portVlan p == vlan)
         || (mode == "trunk" && builtins.elem vlan p.vlans)
      ) allIndices);

    enableBits = bitmask
      (builtins.filter (idx: modeAt idx != "unused") allIndices);

    h2 = n: "0x${toHex 2 n}";
    h8 = n: "0x${toHex 8 n}";

    mkArray = f: "[${builtins.concatStringsSep "," (map f allIndices)}]";

    vlanEntries = map (vlan:
      "{nm:'',mbr:${h8 (vlanMemberBits vlan)},vid:${h2 vlan},piso:0x00,lrn:0x01,mrr:0x00,igmp:0x00}"
    ) switchVlans;
    vlanSection = "vlan.b:[${builtins.concatStringsSep "," vlanEntries}]";

    lacpSection = "lacp.b:{mode:${mkArray (_: "0x00")},sgrp:${mkArray (_: "0x00")}}";
    pwdSection = ".pwd.b:{pwd:''}";
    snmpSection = "snmp.b:{en:0x01,com:'${hexEncodeString "public"}',ci:'',loc:''}";
    rstpSection = "rstp.b:{ena:${h8 allBits}}";

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

    fwdMask = idx: allBits - pow2 idx;

    vlanModeAt = idx: let mode = modeAt idx;
      in if mode == "access" then "0x02"
         else if mode == "trunk" then "0x02"
         else "0x00";

    vlanRecvAt = idx: "0x00";

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

    aclSection = "acl.b:[]";
    hostSection = "host.b:[]";

    backup = builtins.concatStringsSep ","
      [ vlanSection lacpSection pwdSection snmpSection rstpSection
        linkSection fwdSection sysSection aclSection hostSection ];

    portMap = let
      allNames = sortPorts (builtins.attrNames ports);
    in ''
      # SwOS Port Configuration for ${sw.model} (${switchName})
      # Generated from egregore entity data — do not edit manually.
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

  sodola = switchName: let
    sw = topConfig.entities.${switchName}.sodola;
    ports = sw.ports;
    identity = if sw.identity != null then sw.identity else switchName;

    totalPorts = 9;
    allPortIndices = lib.range 0 (totalPorts - 1);

    portName = n: "port${toString n}";

    portCfgN = n: ports.${portName n} or { vlan = null; vlans = []; meta = { host = null; peer = null; description = null; }; };
    portModeN = n: portType (portCfgN n);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;
    mgmtMask = let
      plen = cidrLen topConfig.entities.mgmt.network.ipv4;
      maskBits = n: if n >= 8 then 255 else 256 - pow2 (8 - n);
    in "${toString (maskBits (lib.min plen 8))}.${toString (maskBits (lib.min (lib.max (plen - 8) 0) 8))}.${toString (maskBits (lib.min (lib.max (plen - 16) 0) 8))}.${toString (maskBits (lib.min (lib.max (plen - 24) 0) 8))}";
    mgmtGw = topConfig.entities.mgmt.attrs.gateway4;

    switchVlans = let
      accessVlans = builtins.filter (v: v != null)
        (map (n: portVlan (portCfgN (n + 1))) allPortIndices);
      trunkVlans = builtins.concatLists
        (map (n: (portCfgN (n + 1)).vlans) allPortIndices);
    in lib.sort builtins.lessThan
      (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    userVlans = switchVlans;
    vidTable = [1 1] ++ userVlans
      ++ builtins.genList (_: 65535) (32 - 2 - builtins.length userVlans);

    usedSlots = lib.range 0 (1 + builtins.length userVlans);
    sortIndex = usedSlots
      ++ builtins.genList (_: 65535) (32 - builtins.length usedSlots);

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
      native = if p9.vlan != null then p9.vlan else 1;
    in (if tagged then 1 else 0) + (if native == vlan then 2 else 0);

    vlanAtSlot = slot: builtins.elemAt vidTable slot;

    memberHex = vlan: let
      b1 = memberB1 vlan;
      b2 = memberB2 vlan;
      setA = "00${toHex 2 b1}${toHex 2 b2}00";
      setB = "00${toHex 2 b1}${toHex 2 b2}01";
    in setA + setB;

    vlan1MemberHex = let
      b1 = memberB1 1;
      b2 = memberB2 1;
      setA = "00${toHex 2 b1}${toHex 2 b2}00";
      setB = "00000001";
    in setA + setB;

    vidNameHex = slot: let
      vid = vlanAtSlot slot;
      name = "";
    in if vid == 65535
       then hexRepeat 18 "00"
       else u16hex vid + nullPadHex 16 name;

    blockHex = pos: let
      memSlot = pos + 1;
      vidSlot = pos + 2;
      memVlan = if memSlot < builtins.length vidTable
                then vlanAtSlot memSlot else 65535;
      mem = if memVlan == 65535 then hexRepeat 8 "00"
            else if memVlan == 1 then vlan1MemberHex
            else memberHex memVlan;
      vn = if vidSlot < builtins.length vidTable
           then vidNameHex vidSlot
           else hexRepeat 18 "00";
    in mem + vn;

    allBlocks = lib.concatStrings (map blockHex (lib.range 0 29));

    sec_header =
      "23792379" + "00"
      + ipToHexBytes mgmtIp
      + ipToHexBytes mgmtMask
      + ipToHexBytes mgmtGw
      + hexRepeat 6 "00"
      + nullPadHex 16 "admin"
      + hexRepeat 5 "00"
      + "3c6d3e3d383939696a3069616e3331377a2d7c2a7d2d287e7420707274227377"
      + hexRepeat 20 "00";

    sec_flags =
      "0000020101200801" + "0909"
      + hexRepeat 4 "00"
      + hexRepeat 36 "ffffff00"
      + hexRepeat 50 "00";

    sec_speed =
      "00000000"
      + "06018080"
      + hexRepeat 10 (hexRepeat 9 "01" + "000000");

    sec_rate =
      hexRepeat 24 "00"
      + hexRepeat 9 "00fffff0"
      + hexRepeat 12 "00"
      + hexRepeat 9 "00fffff0"
      + hexRepeat 50 "00"
      + hexRepeat 9 "01ff0000"
      + hexRepeat 10 "00"
      + hexRepeat 9 "00001000"
      ;

    sec_vlantables = let
      nativeVlanHex = lib.concatStrings (map (n:
        u16hex (let p = portCfgN (n + 1); mode = portType p;
        in if mode == "access" then portVlan p
           else if p.vlan != null then p.vlan else 1)
      ) allPortIndices);
      portTypeHex = lib.concatStrings (map (n:
        if portModeN (n + 1) == "access" then "02" else "00"
      ) allPortIndices);
      sortHex = lib.concatStrings (map u16hex sortIndex);
      vidHex = lib.concatStrings (map u16hex vidTable);
    in
      hexRepeat 540 "00"
      + hexRepeat 2 "00"
      + u16hex 1
      + hexRepeat 12 "00"
      + nativeVlanHex
      + hexRepeat 6 "00"
      + portTypeHex
      + "000000"
      + sortHex
      + vidHex
      ;

    sec_vlandata =
      "ffff"
      + "0000"
      + vidNameHex 1
      + allBlocks
      ;

    diagonalMatrix = lib.concatStrings (map (p: let
      row = builtins.genList (b:
        if b == p then "08"
        else if b == p + 2 then "04"
        else "00"
      ) 10;
    in lib.concatStrings row) (lib.range 0 8));

    sec_postVlan =
      hexRepeat 34 "00"
      + diagonalMatrix
      + "04"
      ;

    sec_tail =
      hexRepeat 42 "00"
      + "76adf100"
      + "00020000000a00000000"
      + "0001"
      + "0000"
      + "8000"
      + "14"
      + "02"
      + "0f"
      + lib.concatStrings (map (_: "00000000" + "000000" + "80" + "0000")
          (lib.range 1 9))
      + hexRepeat 30 "00"
      + "00"
      + "00"
      + hexRepeat 5 "00"
      + hexRepeat 9 "01"
      + hexRepeat 4 "00"
      + "00000300" + "00000200" + "00000400" + "00000100"
      + hexRepeat 72 "00"
      + "0000010000000200000003000000040000000500000006000000"
      + "07"
      + nullPadHex 16 "SL902-SWTGW218AS"
      + hexRepeat 10 "00"
      ;

    backup = sec_header + sec_flags + sec_speed + sec_rate
           + sec_vlantables + sec_vlandata + sec_postVlan + sec_tail;

    portMap = let
      allNames = sortPorts (builtins.attrNames ports);
    in ''
      # Sodola Port Configuration for ${sw.model} (${switchName})
      # Generated from egregore entity data — do not edit manually.
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
               (if p.vlans != [] then lib.concatStringsSep "," (map toString p.vlans) else "all")
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

in {
  inherit routeros swos sodola;
}
