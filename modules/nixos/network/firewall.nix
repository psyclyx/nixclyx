{
  path = ["psyclyx" "nixos" "network" "firewall"];
  description = "nftables firewall with port registry";
  extraOptions = {lib, ...}: {
    psyclyx.nixos.network.ports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.coercedTo
        (lib.types.either lib.types.port (lib.types.listOf lib.types.port))
        (v: if builtins.isList v then {tcp = v;} else {tcp = [v];})
        (lib.types.submodule {
          options = {
            tcp = lib.mkOption {
              type = lib.types.listOf lib.types.port;
              default = [];
            };
            udp = lib.mkOption {
              type = lib.types.listOf lib.types.port;
              default = [];
            };
          };
        }));
      default = {};
      description = "Service port registry. Services declare ports here; the firewall collects from it.";
    };
  };
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
  in {
    trustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Interfaces where all traffic is accepted (lo is always implicit).";
    };
    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Additional TCP ports to accept beyond those collected from the registry.";
    };
    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Additional UDP ports to accept beyond those collected from the registry.";
    };
    collectServicePorts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Merge ports from the registry and networking.firewall.allowed*Ports.";
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
    input = lib.mkOption {
      type = lib.types.listOf ruleType;
      default = [];
      description = "Structured input rules inserted after ICMP accept, before port accepts.";
    };
    forward = lib.mkOption {
      type = lib.types.listOf ruleType;
      default = [];
      description = "Structured forwarding rules.";
    };
    masquerade = lib.mkOption {
      type = lib.types.listOf masqueradeRuleType;
      default = [];
      description = "NAT masquerade rules (verdict defaults to masquerade).";
    };
  };
  config = {
    cfg,
    config,
    lib,
    ...
  }: let
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

    hasMasquerade = cfg.masquerade != [];
    hasForward = cfg.forward != [];

    inputRules =
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
      ++ cfg.input
      ++ lib.optional (effectiveTCP != []) {"tcp dport" = effectiveTCP;}
      ++ lib.optional (effectiveUDP != []) {"udp dport" = effectiveUDP;};

    forwardRules =
      [
        {"ct state" = "established,related";}
        {"ct state" = "invalid"; verdict = "drop";}
      ]
      ++ cfg.forward;
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
          family = "ip";
          chains.postrouting = {
            type = "nat";
            hook = "postrouting";
            priority = 100;
            policy = "accept";
            rules = cfg.masquerade;
          };
        };
      };

    boot.kernel.sysctl = lib.mkIf hasForward {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
