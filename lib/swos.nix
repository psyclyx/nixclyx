# swos.nix — Generate a SwOS configuration script.
#
# mkSwOS :: lib -> config -> string
#
# config = {
#   model       : string   — model name (for script comments)
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
# }
#
# Produces a bash script that configures a SwOS switch via its HTTP API.
# Caller computes the port list from whatever data source they have.
lib: config: let
  inherit (builtins) attrNames concatStringsSep foldl' genList elemAt
    hasAttr length map toString stringLength substring;

  # --- Hex encoding -------------------------------------------------------

  byteToHex = v: let
    h = v / 16;
    l = v - h * 16;
    hexDigit = d:
      if d < 10 then toString d
      else elemAt ["a" "b" "c" "d" "e" "f"] (d - 10);
  in "${hexDigit h}${hexDigit l}";

  hexEncodeChar = c: let
    chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";
    hexTable = [
      "30" "31" "32" "33" "34" "35" "36" "37" "38" "39"
      "61" "62" "63" "64" "65" "66" "67" "68" "69" "6a" "6b" "6c" "6d"
      "6e" "6f" "70" "71" "72" "73" "74" "75" "76" "77" "78" "79" "7a"
      "41" "42" "43" "44" "45" "46" "47" "48" "49" "4a" "4b" "4c" "4d"
      "4e" "4f" "50" "51" "52" "53" "54" "55" "56" "57" "58" "59" "5a"
      "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "2a" "2b" "2c"
      "2d" "2e" "2f" "3a" "3b" "3c" "3d" "3e" "3f" "40"
      "5b" "5c" "5d" "5e" "5f" "60" "7b" "7c" "7d" "7e"
    ];
    findIndex = str: idx:
      if idx >= stringLength chars then "3f"
      else if substring idx 1 chars == str then elemAt hexTable idx
      else findIndex str (idx + 1);
  in findIndex c 0;

  hexEncode = s: concatStringsSep "" (map (i:
    hexEncodeChar (substring i 1 s)
  ) (genList (i: i) (stringLength s)));

  ipToHex = ip: let
    parts = lib.splitString "." ip;
  in concatStringsSep "" (map (p: byteToHex (lib.toInt p)) parts);

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

  sys = {
    netmask = "255.255.255.0";
    gateway = "0.0.0.0";
    vlan = 0;
    allowAddress = "0.0.0.0";
    allowNetmask = "0.0.0.0";
    watchdog = false;
  } // config.system;

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

  ports = map (p: let m = portDefaults // p; in m // {
    forceVid =
      if m.forceVid != null then m.forceVid
      else m.vlanMode == "enabled" || m.vlanMode == "strict";
  }) config.ports;

  vlans = config.vlans or {};

  # --- Encoding helpers ---------------------------------------------------

  csv = concatStringsSep ",";
  hex16 = n: "0x${int16LeHex n}";
  bool16 = b: hex16 (if b then 1 else 0);

  vlanModeInt = mode:
    if mode == "disabled" then 0
    else if mode == "optional" then 1
    else if mode == "enabled" then 2
    else if mode == "strict" then 3
    else 0;

  vlanReceiveInt = mode:
    if mode == "any" then 0
    else if mode == "only-tagged" then 1
    else if mode == "only-untagged" then 2
    else 0;

  pow2 = n: if n <= 0 then 1 else 2 * pow2 (n - 1);
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
    "wdog=${int16LeHex (if sys.watchdog then 1 else 0)}"
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
    if vlanIds == [] then ""
    else "&" + concatStringsSep "&" [
      "vlns=${hex16 (length vlanIds)}"
      "vid=${csv (map (v: hex16 v) vlanIds)}"
      "vmb=${csv (map (v: "0x${int32LeHex (portBitmask vlans.${toString v})}") vlanIds)}"
    ];

  fwdPayload = fwdPerPort + vlanTable;

  baseUrl = "http://${sys.address}";
  model = config.model or "SwOS";

in ''
  #!/usr/bin/env bash
  # ${sys.identity} (${model}) configuration — generated.
  # Endpoints: /sys.b  /link.b  /fwd.b
  set -euo pipefail

  BASE_URL="${baseUrl}"
  USER="''${SWOS_USER:-admin}"
  PASS="''${SWOS_PASS:-}"

  curl_post() {
    local endpoint="$1" data="$2"
    curl -s --digest -u "$USER:$PASS" \
      -X POST "$BASE_URL$endpoint" \
      --data-raw "$data"
  }

  echo "Configuring ${sys.identity} (${model}) at ${sys.address}..."

  echo "  /sys.b — system identity, management IP, VLAN ${toString sys.vlan}"
  curl_post /sys.b '${sysPayload}'

  echo "  /link.b — port names, speed, duplex, flow control"
  curl_post /link.b '${linkPayload}'

  echo "  /fwd.b — VLAN forwarding${if vlanIds != [] then " (${toString (length vlanIds)} VLANs)" else ""}"
  curl_post /fwd.b '${fwdPayload}'

  echo "Done."
''
