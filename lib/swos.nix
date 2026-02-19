# swos.nix — Generate a SwOS configuration.
#
# mkSwOS :: lib -> config -> attrset
#
# config = {
#   model       : string   — model name (for readable header)
#   system = {
#     identity      : string — switch hostname
#     address       : string — management IP (dotted quad)
#     netmask       : string — (default: 255.255.255.0)
#     gateway       : string — (default: 0.0.0.0)
#     vlan          : int    — management VLAN (default: 0 = none)
#     allowAddress  : string — allow-from IP (default: 0.0.0.0 = any)
#     allowNetmask  : string — allow-from mask (default: 0.0.0.0)
#     watchdog      : bool   — (default: false)
#   };
#   ports = [{              — one entry per physical port, ordered
#     name        : string   — port label (default: "")
#     enabled     : bool     — (default: true)
#     autoNeg     : bool     — auto-negotiation (default: true)
#     speed       : int      — 0=auto (default: 0)
#     duplex      : int      — 0=auto 1=half 2=full (default: 0)
#     flowControl : bool     — (default: false)
#     pvid        : int      — default VLAN ID (default: 1)
#     vlanMode    : string   — disabled|optional|enabled|strict (default: disabled)
#     forceVid    : bool?    — (default: auto from vlanMode)
#     vlanReceive : string   — any|only-tagged|only-untagged (default: any)
#   }];
#   vlans = {               — VLAN membership table (optional)
#     "<vid>" = [ port-numbers... ];  — 1-indexed member ports
#   };
#   rstp = {                — optional RSTP config
#     ports = [{            — per-port, same length as ports
#       enabled  : bool     — (default: true)
#       pathCost : int      — 0=auto (default: 0)
#       edge     : bool     — (default: false)
#     }];
#   };
#   snmp = {                — optional SNMP config
#     enabled   : bool      — (default: false)
#     community : string    — (default: "public")
#     contact   : string    — (default: "")
#     location  : string    — (default: "")
#   };
#   lacp = [{               — optional LACP config, per-port
#     mode  : string        — off|passive|active (default: off)
#     group : int           — 0=none, 1-16 (default: 0)
#   }];
# }
#
# Returns:
# {
#   model    : string;    — switch model
#   identity : string;    — switch hostname
#   address  : string;    — management IP
#   payloads = {          — URL-encoded POST bodies per endpoint
#     sys  : string;      — /sys.b
#     link : string;      — /link.b
#     fwd  : string;      — /fwd.b
#     rstp : string;      — /rstp.b (if config.rstp present)
#     snmp : string;      — /snmp.b (if config.snmp present)
#     lacp : string;      — /lacp.b (if config.lacp present)
#   };
#   readable : string;    — human-readable config summary
# }
#
# Caller computes the port list from whatever data source they have.
lib: config: let
  inherit
    (builtins)
    attrNames
    concatStringsSep
    foldl'
    genList
    elemAt
    hasAttr
    length
    map
    toString
    stringLength
    substring
    ;

  # --- Hex encoding -------------------------------------------------------

  byteToHex = v: let
    h = v / 16;
    l = v - h * 16;
    hexDigit = d:
      if d < 10
      then toString d
      else elemAt ["a" "b" "c" "d" "e" "f"] (d - 10);
  in "${hexDigit h}${hexDigit l}";

  hexEncodeChar = c: let
    chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";
    hexTable = [
      "30"
      "31"
      "32"
      "33"
      "34"
      "35"
      "36"
      "37"
      "38"
      "39"
      "61"
      "62"
      "63"
      "64"
      "65"
      "66"
      "67"
      "68"
      "69"
      "6a"
      "6b"
      "6c"
      "6d"
      "6e"
      "6f"
      "70"
      "71"
      "72"
      "73"
      "74"
      "75"
      "76"
      "77"
      "78"
      "79"
      "7a"
      "41"
      "42"
      "43"
      "44"
      "45"
      "46"
      "47"
      "48"
      "49"
      "4a"
      "4b"
      "4c"
      "4d"
      "4e"
      "4f"
      "50"
      "51"
      "52"
      "53"
      "54"
      "55"
      "56"
      "57"
      "58"
      "59"
      "5a"
      "20"
      "21"
      "22"
      "23"
      "24"
      "25"
      "26"
      "27"
      "28"
      "29"
      "2a"
      "2b"
      "2c"
      "2d"
      "2e"
      "2f"
      "3a"
      "3b"
      "3c"
      "3d"
      "3e"
      "3f"
      "40"
      "5b"
      "5c"
      "5d"
      "5e"
      "5f"
      "60"
      "7b"
      "7c"
      "7d"
      "7e"
    ];
    findIndex = str: idx:
      if idx >= stringLength chars
      then "3f"
      else if substring idx 1 chars == str
      then elemAt hexTable idx
      else findIndex str (idx + 1);
  in
    findIndex c 0;

  hexEncode = s:
    concatStringsSep "" (map (
      i:
        hexEncodeChar (substring i 1 s)
    ) (genList (i: i) (stringLength s)));

  ipToHex = ip: let
    parts = lib.splitString "." ip;
  in
    concatStringsSep "" (map (p: byteToHex (lib.toInt p)) parts);

  int16LeHex = n: let
    lo = n - (n / 256) * 256;
    hi = n / 256;
  in "${byteToHex lo}${byteToHex hi}";

  int32LeHex = n: let
    b0 = n - (n / 256) * 256;
    n1 = n / 256;
    b1 = n1 - (n1 / 256) * 256;
    n2 = n1 / 256;
    b2 = n2 - (n2 / 256) * 256;
    b3 = n2 / 256;
  in "${byteToHex b0}${byteToHex b1}${byteToHex b2}${byteToHex b3}";

  # --- Defaults -----------------------------------------------------------

  sys =
    {
      netmask = "255.255.255.0";
      gateway = "0.0.0.0";
      vlan = 0;
      allowAddress = "0.0.0.0";
      allowNetmask = "0.0.0.0";
      watchdog = false;
    }
    // config.system;

  portDefaults = {
    name = "";
    enabled = true;
    autoNeg = true;
    speed = 0;
    duplex = 0;
    flowControl = false;
    pvid = 1;
    vlanMode = "disabled";
    forceVid = null;
    vlanReceive = "any";
  };

  ports = map (p: let
    m = portDefaults // p;
  in
    m
    // {
      forceVid =
        if m.forceVid != null
        then m.forceVid
        else m.vlanMode == "enabled" || m.vlanMode == "strict";
    })
  config.ports;

  vlans = config.vlans or {};

  # --- Encoding helpers ---------------------------------------------------

  csv = concatStringsSep ",";
  hex16 = n: "0x${int16LeHex n}";
  bool16 = b:
    hex16 (
      if b
      then 1
      else 0
    );

  hex8 = n: "0x${byteToHex n}";
  bool8 = b:
    hex8 (
      if b
      then 1
      else 0
    );

  vlanModeInt = mode:
    if mode == "disabled"
    then 0
    else if mode == "optional"
    then 1
    else if mode == "enabled"
    then 2
    else if mode == "strict"
    then 3
    else 0;

  vlanReceiveInt = mode:
    if mode == "any"
    then 0
    else if mode == "only-tagged"
    then 1
    else if mode == "only-untagged"
    then 2
    else 0;

  lacpModeInt = mode:
    if mode == "off"
    then 0
    else if mode == "passive"
    then 1
    else if mode == "active"
    then 2
    else 0;

  pow2 = n:
    if n <= 0
    then 1
    else 2 * pow2 (n - 1);
  portBitmask = portNums: foldl' (acc: p: acc + pow2 (p - 1)) 0 portNums;

  # --- /sys.b —  system ---------------------------------------------------

  sysPayload = concatStringsSep "&" [
    "id=${hexEncode sys.identity}"
    "ip=${ipToHex sys.address}"
    "nm=${ipToHex sys.netmask}"
    "gw=${ipToHex sys.gateway}"
    "vlni=${int16LeHex sys.vlan}"
    "aip=${ipToHex sys.allowAddress}"
    "anm=${ipToHex sys.allowNetmask}"
    "wdog=${int16LeHex (
      if sys.watchdog
      then 1
      else 0
    )}"
  ];

  # --- /link.b — port link settings ---------------------------------------

  linkPayload = concatStringsSep "&" [
    "nm=${csv (map (p: hexEncode p.name) ports)}"
    "en=${csv (map (p: bool16 p.enabled) ports)}"
    "an=${csv (map (p: bool16 p.autoNeg) ports)}"
    "spd=${csv (map (p: hex16 p.speed) ports)}"
    "dpx=${csv (map (p: hex16 p.duplex) ports)}"
    "fc=${csv (map (p: bool16 p.flowControl) ports)}"
  ];

  # --- /fwd.b — forwarding / VLAN -----------------------------------------

  fwdPerPort = concatStringsSep "&" [
    "dvid=${csv (map (p: hex16 p.pvid) ports)}"
    "vlni=${csv (map (p: hex16 (vlanModeInt p.vlanMode)) ports)}"
    "fvid=${csv (map (p: bool16 p.forceVid) ports)}"
    "vlnr=${csv (map (p: hex16 (vlanReceiveInt p.vlanReceive)) ports)}"
  ];

  # VLAN membership table: per-VLAN port bitmask.
  vlanIds = lib.sort (a: b: a < b) (map lib.toInt (attrNames vlans));
  vlanTable =
    if vlanIds == []
    then ""
    else
      "&"
      + concatStringsSep "&" [
        "vlns=${hex16 (length vlanIds)}"
        "vid=${csv (map (v: hex16 v) vlanIds)}"
        "vmb=${csv (map (v: "0x${int32LeHex (portBitmask vlans.${toString v})}") vlanIds)}"
      ];

  fwdPayload = fwdPerPort + vlanTable;

  model = config.model or "SwOS";

  # --- /rstp.b — RSTP (optional) ---------------------------------------------

  rstpPortDefaults = {
    enabled = true;
    pathCost = 0;
    edge = false;
  };

  rstpPorts = map (p: rstpPortDefaults // p) config.rstp.ports;

  rstpPayload = concatStringsSep "&" [
    "rstp=${csv (map (p: bool16 p.enabled) rstpPorts)}"
    "rpc=${csv (map (p: "0x${int32LeHex p.pathCost}") rstpPorts)}"
    "edge=${csv (map (p: bool16 p.edge) rstpPorts)}"
  ];

  # --- /snmp.b — SNMP (optional) ---------------------------------------------

  snmpDefaults = {
    enabled = false;
    community = "public";
    contact = "";
    location = "";
  };

  snmpCfg = snmpDefaults // config.snmp;

  snmpPayload = concatStringsSep "&" [
    "en=${hex8 (if snmpCfg.enabled then 1 else 0)}"
    "com=${hexEncode snmpCfg.community}"
    "ci=${hexEncode snmpCfg.contact}"
    "loc=${hexEncode snmpCfg.location}"
  ];

  # --- /lacp.b — LACP (optional) ---------------------------------------------

  lacpPortDefaults = {
    mode = "off";
    group = 0;
  };

  lacpPorts = map (p: lacpPortDefaults // p) config.lacp;

  lacpPayload = concatStringsSep "&" [
    "mode=${csv (map (p: hex8 (lacpModeInt p.mode)) lacpPorts)}"
    "grp=${csv (map (p: hex8 p.group) lacpPorts)}"
  ];

  # --- Diff reference (human-readable expected values for GET comparison) ------

  portNum = i: let s = toString (i + 1); in
    if i + 1 < 10 then "0${s}" else s;

  portNamesList = map (p: p.name) ports;

  portNamesStr = concatStringsSep "\n" portNamesList + "\n";

  boolStr = b: if b then "yes" else "no";

  # mkPerPortDiffRef :: [attrset] -> [{displayName, valueFn}] -> string
  # Emits per-port groups with headers and sorted fields.
  mkPerPortDiffRef = portConfigs: fields: let
    sortedFields = lib.sort (a: b: a.displayName < b.displayName) fields;
  in concatStringsSep "" (lib.imap0 (i: pc: let
    num = portNum i;
    name = elemAt portNamesList i;
    header = "# Port ${num}: ${name}\n";
    fieldLines = map (f: "${num}.${f.displayName}=${f.valueFn pc}\n") sortedFields;
  in header + concatStringsSep "" fieldLines) portConfigs);

  # --- sys (scalar) ---

  sysDiffRef = concatStringsSep "\n" (lib.sort (a: b: a < b) [
    "address=${sys.address}"
    "identity=${sys.identity}"
    "mgmtVlan=${toString sys.vlan}"
  ]) + "\n";
  sysDiffSpec = "avln\tint16\tmgmtVlan\nid\tstr\tidentity\nip\tip\taddress\n";

  # --- link (per-port) ---

  linkDiffRef = mkPerPortDiffRef ports [
    { displayName = "autoNeg"; valueFn = p: boolStr p.autoNeg; }
    { displayName = "enabled"; valueFn = p: boolStr p.enabled; }
    { displayName = "name"; valueFn = p: p.name; }
    { displayName = "speed"; valueFn = p: toString p.speed; }
  ];
  linkDiffSpec = "an\tports\tautoNeg\t0:no,1:yes\nen\tports\tenabled\t0:no,1:yes\nnm\tarray-str\tname\nspdc\tarray-int8\tspeed\n";

  # --- fwd (per-port) ---

  fwdDiffRef = mkPerPortDiffRef ports [
    { displayName = "forceVid"; valueFn = p: boolStr p.forceVid; }
    { displayName = "pvid"; valueFn = p: toString p.pvid; }
    { displayName = "vlanMode"; valueFn = p: p.vlanMode; }
  ];
  fwdDiffSpec = "dvid\tarray-int16\tpvid\nfvid\tports\tforceVid\t0:no,1:yes\nvlan\tarray-int8\tvlanMode\t0:disabled,1:optional,2:enabled,3:strict\n";

  # --- rstp (per-port) ---

  rstpDiffRef = mkPerPortDiffRef rstpPorts [
    { displayName = "edge"; valueFn = p: boolStr p.edge; }
    { displayName = "enabled"; valueFn = p: boolStr p.enabled; }
    { displayName = "pathCost"; valueFn = p: toString p.pathCost; }
  ];
  rstpDiffSpec = "edge\tports\tedge\t0:no,1:yes\nrpc\tarray-int32\tpathCost\nrstp\tports\tenabled\t0:no,1:yes\n";

  # --- snmp (scalar) ---

  snmpDiffRef = concatStringsSep "\n" (lib.sort (a: b: a < b) [
    "community=${snmpCfg.community}"
    "contact=${snmpCfg.contact}"
    "enabled=${boolStr snmpCfg.enabled}"
    "location=${snmpCfg.location}"
  ]) + "\n";
  snmpDiffSpec = "ci\tstr\tcontact\ncom\tstr\tcommunity\nen\tint8\tenabled\t0:no,1:yes\nloc\tstr\tlocation\n";

  # --- lacp (per-port) ---

  lacpDiffRef = mkPerPortDiffRef lacpPorts [
    { displayName = "group"; valueFn = p: toString p.group; }
    { displayName = "mode"; valueFn = p: p.mode; }
  ];
  lacpDiffSpec = "grp\tarray-int8\tgroup\nmode\tarray-int8\tmode\t0:off,1:passive,2:active\n";

  # --- Readable config --------------------------------------------------------

  padRight = w: s: let
    pad = w - stringLength s;
  in s + concatStringsSep "" (genList (_: " ") (if pad > 0 then pad else 0));

  padLeft = w: s: let
    pad = w - stringLength s;
  in concatStringsSep "" (genList (_: " ") (if pad > 0 then pad else 0)) + s;

  portLines = lib.imap1 (i: p: let
    num = padLeft 4 (toString i);
    name = padRight 20 p.name;
    pvid = padRight 10 "PVID=${toString p.pvid}";
  in "  ${num}  ${name} ${pvid} VLAN=${p.vlanMode}") ports;

  vlanLines = map (vid: let
    memberPorts = vlans.${toString vid};
    members = concatStringsSep ", " (map toString memberPorts);
  in "  ${padLeft 4 (toString vid)}: ports ${members}") vlanIds;

  rstpLines = lib.optionals (config ? rstp) ([
    ""
    "## RSTP"
  ] ++ lib.imap1 (i: rp: let
    name = padRight 20 (elemAt ports (i - 1)).name;
    num = padLeft 4 (toString i);
    en = if rp.enabled then "enabled " else "disabled";
    cost = if rp.pathCost == 0 then "cost=auto" else "cost=${toString rp.pathCost}";
    edge = if rp.edge then "  edge" else "";
  in "  ${num}  ${name} ${en}  ${cost}${edge}") rstpPorts);

  snmpLines = lib.optionals (config ? snmp) [
    ""
    "## SNMP"
    "  Enabled:    ${if snmpCfg.enabled then "yes" else "no"}"
    "  Community:  ${snmpCfg.community}"
    "  Contact:    ${snmpCfg.contact}"
    "  Location:   ${snmpCfg.location}"
  ];

  lacpLines = lib.optionals (config ? lacp) ([
    ""
    "## LACP"
  ] ++ lib.imap1 (i: lp: let
    name = padRight 20 (elemAt ports (i - 1)).name;
    num = padLeft 4 (toString i);
    mode = padRight 8 lp.mode;
    grp = if lp.group == 0 then "group=none" else "group=${toString lp.group}";
  in "  ${num}  ${name} ${mode} ${grp}") lacpPorts);

  readableConfig = concatStringsSep "\n" ([
    "# ${sys.identity} (${model}) — ${sys.address}"
    ""
    "## System"
    "  Identity:   ${sys.identity}"
    "  Address:    ${sys.address}/${sys.netmask}"
    "  Gateway:    ${sys.gateway}"
    "  Mgmt VLAN:  ${toString sys.vlan}"
    "  Allow from: ${sys.allowAddress}/${sys.allowNetmask}"
    "  Watchdog:   ${if sys.watchdog then "yes" else "no"}"
    ""
    "## Ports (${toString (length ports)})"
  ] ++ portLines ++ [
    ""
    "## VLANs (${toString (length vlanIds)})"
  ] ++ vlanLines
    ++ rstpLines
    ++ snmpLines
    ++ lacpLines
    ++ [""]);

in {
  inherit model;
  identity = sys.identity;
  address = sys.address;
  payloads = {
    sys = sysPayload;
    link = linkPayload;
    fwd = fwdPayload;
  }
  // lib.optionalAttrs (config ? rstp) { rstp = rstpPayload; }
  // lib.optionalAttrs (config ? snmp) { snmp = snmpPayload; }
  // lib.optionalAttrs (config ? lacp) { lacp = lacpPayload; };
  readable = readableConfig;
  diffRefs = {
    sys = sysDiffRef;
    link = linkDiffRef;
    fwd = fwdDiffRef;
  }
  // lib.optionalAttrs (config ? rstp) { rstp = rstpDiffRef; }
  // lib.optionalAttrs (config ? snmp) { snmp = snmpDiffRef; }
  // lib.optionalAttrs (config ? lacp) { lacp = lacpDiffRef; };
  diffSpecs = {
    sys = sysDiffSpec;
    link = linkDiffSpec;
    fwd = fwdDiffSpec;
  }
  // lib.optionalAttrs (config ? rstp) { rstp = rstpDiffSpec; }
  // lib.optionalAttrs (config ? snmp) { snmp = snmpDiffSpec; }
  // lib.optionalAttrs (config ? lacp) { lacp = lacpDiffSpec; };
  portNames = portNamesStr;
}
