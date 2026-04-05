{
  path = ["psyclyx" "nixos" "network" "firewall"];
  description = "nftables firewall";
  options = {lib, ...}: let
    nftTypes = import ./types.nix lib;
    inherit (nftTypes) ruleType;

    zoneInputType = lib.types.submodule {
      options = {
        policy = lib.mkOption {
          type = lib.types.enum ["accept" "drop"];
          default = "drop";
          description = "Default verdict for unmatched traffic on this zone.";
        };
        allowICMP = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Accept standard ICMP/ICMPv6 traffic on this zone.
            Enables: echo-request, destination-unreachable, time-exceeded,
            parameter-problem, packet-too-big (v6).
          '';
        };
        allowedTCPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [];
          description = "TCP ports to accept on this zone.";
        };
        allowedUDPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [];
          description = "UDP ports to accept on this zone.";
        };
        rules = lib.mkOption {
          type = lib.types.listOf ruleType;
          default = [];
          description = "Additional structured input rules for this zone.";
        };
      };
    };

    zoneType = lib.types.submodule {
      options = {
        interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Interfaces belonging to this zone.";
        };
      };
    };

    forwardRuleType = lib.types.submodule {
      options = {
        from = lib.mkOption {
          type = lib.types.str;
          description = "Source zone name.";
        };
        to = lib.mkOption {
          type = lib.types.str;
          description = "Destination zone name.";
        };
        rules = lib.mkOption {
          type = lib.types.listOf ruleType;
          default = [];
          description = ''
            Additional match criteria for this forward rule. When empty,
            all traffic from source to destination zone is accepted.
            When non-empty, only traffic matching these rules is accepted.
          '';
        };
      };
    };

    masqueradeZoneType = lib.types.submodule {
      options = {
        from = lib.mkOption {
          type = lib.types.str;
          description = "Source zone name.";
        };
        to = lib.mkOption {
          type = lib.types.str;
          description = "Destination zone name.";
        };
      };
    };
  in {
    zones = lib.mkOption {
      type = lib.types.attrsOf zoneType;
      default = {};
      description = ''
        Named interface groups. All firewall rules are scoped to zones.
      '';
    };
    input = lib.mkOption {
      type = lib.types.attrsOf zoneInputType;
      default = {};
      description = ''
        Per-zone input policy and rules. Keys must match zone names.
        Zones not listed here get default policy "drop" with allowICMP = true.
      '';
    };
    forward = lib.mkOption {
      type = lib.types.listOf forwardRuleType;
      default = [];
      description = "Zone-to-zone forwarding rules.";
    };
    masquerade = lib.mkOption {
      type = lib.types.listOf masqueradeZoneType;
      default = [];
      description = "Zone-to-zone NAT masquerade rules.";
    };
    synFloodProtection = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Add syn-flood rate-limiting chain.";
      };
      rate = lib.mkOption {
        type = lib.types.str;
        default = "25/second";
        description = "nftables rate expression for SYN flood limiting.";
      };
      burst = lib.mkOption {
        type = lib.types.int;
        default = 50;
        description = "Burst packets for SYN flood limiting.";
      };
    };
  };
  config = {
    cfg,
    config,
    lib,
    ...
  }: let
    zoneInputCfg = name:
      cfg.input.${name} or {policy = "drop"; allowICMP = true; allowedTCPPorts = []; allowedUDPPorts = []; rules = [];};

    icmpRules = zone: let
      zi = zoneInputCfg zone;
      ifaces = cfg.zones.${zone}.interfaces;
    in lib.optionals zi.allowICMP [
      {iifname = ifaces; "icmp type" = "{ echo-request, destination-unreachable, time-exceeded }"; comment = "${zone}: icmpv4";}
      {iifname = ifaces; "icmpv6 type" = "{ echo-request, destination-unreachable, time-exceeded, packet-too-big, nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert }"; comment = "${zone}: icmpv6";}
    ];

    zoneInputRules = zone: let
      zi = zoneInputCfg zone;
      ifaces = cfg.zones.${zone}.interfaces;
    in
      if zi.policy == "accept"
      then [{iifname = ifaces; comment = "${zone}: accept all";}]
      else
        (icmpRules zone)
        ++ map (r: r // {iifname = ifaces;}) zi.rules
        ++ lib.optional (zi.allowedTCPPorts != []) {iifname = ifaces; "tcp dport" = zi.allowedTCPPorts; comment = "${zone}: tcp";}
        ++ lib.optional (zi.allowedUDPPorts != []) {iifname = ifaces; "udp dport" = zi.allowedUDPPorts; comment = "${zone}: udp";};

    # Order: accept-policy zones first (early exit), then restricted zones
    acceptZones = lib.filterAttrs (n: _: (zoneInputCfg n).policy == "accept") cfg.zones;
    restrictedZones = lib.filterAttrs (n: _: (zoneInputCfg n).policy != "accept") cfg.zones;

    inputRules =
      [{iif = "lo";}]
      ++ [
        {"ct state" = "established,related";}
        {"ct state" = "invalid"; verdict = "drop";}
      ]
      ++ lib.optional cfg.synFloodProtection.enable
        {"tcp flags" = "syn"; verdict = "jump syn-flood";}
      ++ lib.concatMap (zone: zoneInputRules zone) (lib.attrNames acceptZones)
      ++ lib.concatMap (zone: zoneInputRules zone) (lib.attrNames restrictedZones);

    forwardRules =
      [
        {"ct state" = "established,related";}
        {"ct state" = "invalid"; verdict = "drop";}
      ]
      ++ lib.concatMap (fwd: let
        fromIfaces = cfg.zones.${fwd.from}.interfaces;
        toIfaces = cfg.zones.${fwd.to}.interfaces;
      in
        if fwd.rules == []
        then [{iifname = fromIfaces; oifname = toIfaces; comment = "${fwd.from} -> ${fwd.to}";}]
        else map (r: r // {iifname = fromIfaces; oifname = toIfaces;}) fwd.rules
      ) cfg.forward;

    masqueradeRules =
      map (m: {
        iifname = cfg.zones.${m.from}.interfaces;
        oifname = cfg.zones.${m.to}.interfaces;
        verdict = "masquerade";
        comment = "nat: ${m.from} -> ${m.to}";
      }) cfg.masquerade;

    hasMasquerade = masqueradeRules != [];
  in
    lib.mkIf (cfg.zones != {}) {
      networking.firewall.enable = false;

      psyclyx.nixos.network.nftables.tables =
        {
          filter = {
            family = "inet";
            chains =
              {
                input = {
                  type = "filter";
                  hook = "input";
                  priority = 0;
                  policy = "drop";
                  rules = inputRules;
                };
                forward = {
                  type = "filter";
                  hook = "forward";
                  priority = 0;
                  policy = "drop";
                  rules = forwardRules;
                };
                output = {
                  type = "filter";
                  hook = "output";
                  priority = 0;
                  policy = "accept";
                };
              }
              // lib.optionalAttrs cfg.synFloodProtection.enable {
                syn-flood.rules = [
                  {"limit rate" = "${cfg.synFloodProtection.rate} burst ${toString cfg.synFloodProtection.burst} packets"; verdict = "return";}
                  {verdict = "drop";}
                ];
              };
          };
        }
        // lib.optionalAttrs hasMasquerade {
          nat = {
            family = "inet";
            chains.postrouting = {
              type = "nat";
              hook = "postrouting";
              priority = 100;
              policy = "accept";
              rules = masqueradeRules;
            };
          };
        };

      boot.kernel.sysctl = lib.mkIf (cfg.forward != []) {
        "net.ipv4.ip_forward" = lib.mkDefault 1;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
      };
    };
}
