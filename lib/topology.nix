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

  reverseNibbles = width: hex: let
    padded = lib.fixedWidthString width "0" hex;
    chars = lib.stringToCharacters padded;
  in
    lib.concatStringsSep "." (lib.reverseList chars);

  # Only supports /24 subnets — asserts if given anything else.
  parseCidrPrefix = cidr: let
    parts = lib.splitString "/" cidr;
    addr = builtins.head parts;
    len = lib.toInt (builtins.elemAt parts 1);
    octets = lib.splitString "." addr;
    prefix = lib.concatStringsSep "." (lib.take 3 octets);
  in
    assert len == 24 || throw "parseCidrPrefix: only /24 supported, got /${toString len} for ${cidr}";
    {inherit prefix len;};

  ulaReverseBase = let
    stripped = lib.replaceStrings [":"] [""] ulaPrefix;
    chars = lib.stringToCharacters stripped;
  in
    lib.concatStringsSep "." (lib.reverseList chars);

  enrichNetwork = name: net: let
    parsed = parseCidrPrefix net.ipv4;
    hex = net.ulaSubnetHex;
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
      zoneName = "${name}.${topo.domains.home}";
      ip6Reverse = reverseNibbles 4 hex;
    };

  networks = lib.mapAttrs enrichNetwork topo.networks;

  dhcpVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: net: net.vlan) topo.networks);

  vlanNameMap = builtins.listToAttrs (lib.mapAttrsToList (name: net:
    lib.nameValuePair (toString net.vlan) name
  ) topo.networks);

  hostAddress4 = network: host:
    if host.addresses ? ${network} && host.addresses.${network}.ipv4 != null
    then host.addresses.${network}.ipv4
    else throw "Host has no IPv4 on network '${network}'.";

  hostAddress6 = network: host:
    if host.addresses ? ${network} && host.addresses.${network}.ipv6 != null
    then host.addresses.${network}.ipv6
    else throw "Host has no IPv6 on network '${network}'.";
in {
  inherit networks ulaReverseBase vlanNameMap dhcpVlans hostAddress4 hostAddress6;
  utils = {inherit intToHex parseCidrPrefix; inherit (lib) reverseList;
    hexToReverseNibbles = reverseNibbles 4;
    hostReverseNibbles = reverseNibbles 16;
  };
}
