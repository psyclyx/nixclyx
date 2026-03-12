{
  path = ["psyclyx" "nixos" "network" "firewall"];
  description = "nftables firewall";
  options = {lib, ...}: let
    ruleValueType = lib.mkOptionType {
      name = "nftables-rule-value";
      description = "string, int, bool, or list of strings/ints";
      check = v:
        builtins.isString v || builtins.isInt v || builtins.isBool v
        || (builtins.isList v
          && (v == [] || builtins.all builtins.isString v || builtins.all builtins.isInt v));
      merge = lib.options.mergeEqualOption;
    };

    ruleType = lib.types.submodule {
      freeformType = lib.types.attrsOf ruleValueType;
      options.verdict = lib.mkOption {
        type = lib.types.str;
        default = "accept";
      };
      options.comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

    masqueradeRuleType = lib.types.submodule {
      freeformType = lib.types.attrsOf ruleValueType;
      options.verdict = lib.mkOption {
        type = lib.types.str;
        default = "masquerade";
      };
      options.comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

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
        Named interface groups. When zones are defined, all firewall rules
        are scoped to zones. When empty, falls back to legacy mode
        (trustedInterfaces + global port allows).
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

    # Legacy options (used when zones = {})
    trustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Legacy: interfaces where all traffic is accepted.";
    };
    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Legacy: TCP ports to accept globally.";
    };
    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Legacy: UDP ports to accept globally.";
    };
    collectServicePorts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Legacy: merge ports from the port registry and networking.firewall.allowed*Ports.";
    };
    legacyInput = lib.mkOption {
      type = lib.types.listOf ruleType;
      default = [];
      description = "Legacy: structured input rules (used when zones = {}).";
    };
    legacyForward = lib.mkOption {
      type = lib.types.listOf ruleType;
      default = [];
      description = "Legacy: structured forwarding rules (used when zones = {}).";
    };
    legacyMasquerade = lib.mkOption {
      type = lib.types.listOf masqueradeRuleType;
      default = [];
      description = "Legacy: NAT masquerade rules (used when zones = {}).";
    };
  };
  config = {
    cfg,
    config,
    lib,
    ...
  }: let
    useZones = cfg.zones != {};

    # ── Zone mode ──────────────────────────────────────────────────────

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

    zoneInputChain =
      [{iif = "lo";}]
      ++ [
        {"ct state" = "established,related";}
        {"ct state" = "invalid"; verdict = "drop";}
      ]
      ++ lib.optional cfg.synFloodProtection.enable
        {"tcp flags" = "syn"; verdict = "jump syn-flood";}
      ++ lib.concatMap (zone: zoneInputRules zone) (lib.attrNames acceptZones)
      ++ lib.concatMap (zone: zoneInputRules zone) (lib.attrNames restrictedZones);

    zoneForwardChain =
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

    zoneMasqueradeChain =
      map (m: {
        iifname = cfg.zones.${m.from}.interfaces;
        oifname = cfg.zones.${m.to}.interfaces;
        verdict = "masquerade";
        comment = "nat: ${m.from} -> ${m.to}";
      }) cfg.masquerade;

    # ── Legacy mode ────────────────────────────────────────────────────

    ports = config.psyclyx.nixos.network.ports;
    registryTCP = lib.concatMap (p: p.tcp) (lib.attrValues ports);
    registryUDP = lib.concatMap (p: p.udp) (lib.attrValues ports);
    nixosTCP = config.networking.firewall.allowedTCPPorts;
    nixosUDP = config.networking.firewall.allowedUDPPorts;

    effectiveTCP =
      if cfg.collectServicePorts
      then lib.unique (cfg.allowedTCPPorts ++ registryTCP ++ nixosTCP)
      else lib.unique cfg.allowedTCPPorts;
    effectiveUDP =
      if cfg.collectServicePorts
      then lib.unique (cfg.allowedUDPPorts ++ registryUDP ++ nixosUDP)
      else lib.unique cfg.allowedUDPPorts;

    legacyInputRules =
      [{iif = "lo";}]
      ++ lib.optional (cfg.trustedInterfaces != []) {iifname = cfg.trustedInterfaces;}
      ++ [
        {"ct state" = "established,related";}
        {"ct state" = "invalid"; verdict = "drop";}
        {"ip protocol" = "icmp";}
        {"ip6 nexthdr" = "icmpv6";}
      ]
      ++ lib.optional cfg.synFloodProtection.enable
        {"tcp flags" = "syn"; verdict = "jump syn-flood";}
      ++ cfg.legacyInput
      ++ lib.optional (effectiveTCP != []) {"tcp dport" = effectiveTCP;}
      ++ lib.optional (effectiveUDP != []) {"udp dport" = effectiveUDP;};

    legacyForwardRules =
      [
        {"ct state" = "established,related";}
        {"ct state" = "invalid"; verdict = "drop";}
      ]
      ++ cfg.legacyForward;

    # ── Shared ─────────────────────────────────────────────────────────

    inputRules = if useZones then zoneInputChain else legacyInputRules;
    forwardRules = if useZones then zoneForwardChain else legacyForwardRules;
    masqueradeRules = if useZones then zoneMasqueradeChain else cfg.legacyMasquerade;

    hasMasquerade = masqueradeRules != [];
    hasForward = forwardRules != [
      {"ct state" = "established,related";}
      {"ct state" = "invalid"; verdict = "drop";}
    ];
  in {
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

    boot.kernel.sysctl = lib.mkIf (cfg.forward != [] || cfg.legacyForward != []) {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
