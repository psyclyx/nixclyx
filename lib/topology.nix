lib: topo: let
  conventions = topo.conventions;
  ulaPrefix = topo.ipv6UlaPrefix;

  intToHex = n: let
    hexDigits = ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"];
    toHexDigit = d: builtins.elemAt hexDigits d;
    go = x:
      if x < 16
      then toHexDigit x
      else (go (x / 16)) + toHexDigit (lib.mod x 16);
  in
    go n;

  hexToReverseNibbles = hex: let
    padded = lib.fixedWidthString 4 "0" hex;
    chars = lib.stringToCharacters padded;
    reversed = lib.reverseList chars;
  in
    lib.concatStringsSep "." reversed;

  hostReverseNibbles = hexStr: let
    padded = lib.fixedWidthString 16 "0" hexStr;
    chars = lib.stringToCharacters padded;
    reversed = lib.reverseList chars;
  in
    lib.concatStringsSep "." reversed;

  parseCidrPrefix = cidr: let
    parts = lib.splitString "/" cidr;
    addr = builtins.head parts;
    len = lib.toInt (builtins.elemAt parts 1);
    octets = lib.splitString "." addr;
    prefix = lib.concatStringsSep "." (lib.take 3 octets);
  in {inherit prefix len;};

  ulaReverseBase = let
    stripped = lib.replaceStrings [":"] [""] ulaPrefix;
    chars = lib.stringToCharacters stripped;
    reversed = lib.reverseList chars;
  in
    lib.concatStringsSep "." reversed;

  enrichNetwork = name: net: let
    parsed = parseCidrPrefix net.ipv4;
    hex = net.ipv6Suffix;
    prefix6 = "${ulaPrefix}:${hex}";
  in
    net
    // {
      prefix = parsed.prefix;
      prefixLen = parsed.len;
      gateway4 = "${parsed.prefix}.${toString conventions.gatewayOffset}";
      gateway6 = "${prefix6}::${intToHex conventions.gatewayOffset}";
      subnet6 = "${prefix6}::/64";
      vlanHex = hex;
      zoneName = "${name}.${conventions.homeDomain}";
      ip6Reverse = hexToReverseNibbles hex;
      pool4Start = "${parsed.prefix}.${toString conventions.dhcpPool.start}";
      pool4End = "${parsed.prefix}.${toString conventions.dhcpPool.end}";
      pool6Start = "${prefix6}::100";
      pool6End = "${prefix6}::1ff";
    };

  networks = lib.mapAttrs enrichNetwork topo.networks;

  dhcpVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: net: net.vlan) topo.networks);

  vlanNameMap = builtins.listToAttrs (lib.mapAttrsToList (name: net:
    lib.nameValuePair (toString net.vlan) name
  ) topo.networks);

  # Resolve a host's IPv4 address on a given network.
  # Checks host.addresses.${network}.ipv4 first, falls back to convention math.
  hostAddress4 = network: host:
    if host.addresses ? ${network} && host.addresses.${network}.ipv4 != null
    then host.addresses.${network}.ipv4
    else "${networks.${network}.prefix}.${toString (conventions.hostBaseOffset + host.labIndex)}";

  # Resolve a host's IPv6 address on a given network.
  # Checks host.addresses.${network}.ipv6 first, falls back to convention math.
  hostAddress6 = network: host: let
    net = networks.${network};
    prefix6 = "${ulaPrefix}:${net.vlanHex}";
  in
    if host.addresses ? ${network} && host.addresses.${network}.ipv6 != null
    then host.addresses.${network}.ipv6
    else "${prefix6}::${intToHex (conventions.hostBaseOffset + host.labIndex)}";
in {
  inherit networks ulaReverseBase vlanNameMap dhcpVlans hostAddress4 hostAddress6;
  utils = {inherit intToHex hexToReverseNibbles hostReverseNibbles parseCidrPrefix;};
}
