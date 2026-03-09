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
  options = {lib, ...}: {
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
    chains = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      description = "Custom chains in table inet filter.";
    };
    inputRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Rules inserted after ICMP accept, before port accepts.";
    };
    forwardRules = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          from = lib.mkOption {type = lib.types.listOf lib.types.str;};
          to = lib.mkOption {type = lib.types.listOf lib.types.str;};
        };
      });
      default = [];
      description = "Forwarding pairs (from/to are lists of interface names).";
    };
    masqueradeRules = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          from = lib.mkOption {type = lib.types.listOf lib.types.str;};
          to = lib.mkOption {type = lib.types.listOf lib.types.str;};
        };
      });
      default = [];
      description = "NAT masquerade pairs.";
    };
    synFloodProtection = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Add syn-flood chain + jump via chains/inputRules.";
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
    extraForwardRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Raw nftables appended to the forward chain.";
    };
    extraRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Raw nftables appended after all tables.";
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

    # SYN flood protection contributes to chains + inputRules
    synChains =
      if cfg.synFloodProtection.enable
      then {
        syn-flood = ''
          limit rate ${cfg.synFloodProtection.rate} burst ${toString cfg.synFloodProtection.burst} packets return
          drop
        '';
      }
      else {};

    synInputRules =
      if cfg.synFloodProtection.enable
      then "tcp flags syn jump syn-flood"
      else "";

    allChains = synChains // cfg.chains;
    allInputRules = lib.concatStringsSep "\n" (lib.filter (s: s != "") [
      synInputRules
      cfg.inputRules
    ]);

    chainsText = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: body: ''
      chain ${name} {
        ${body}
      }
    '') allChains);

    trustedText =
      if cfg.trustedInterfaces != []
      then ''iifname { ${lib.concatMapStringsSep ", " (i: ''"${i}"'') cfg.trustedInterfaces} } accept''
      else "";

    tcpAccept =
      if effectiveTCP != []
      then "tcp dport { ${lib.concatMapStringsSep ", " toString effectiveTCP} } accept"
      else "";

    udpAccept =
      if effectiveUDP != []
      then "udp dport { ${lib.concatMapStringsSep ", " toString effectiveUDP} } accept"
      else "";

    forwardEntries = lib.concatMapStringsSep "\n" (rule: let
      fromSet = lib.concatMapStringsSep ", " (i: ''"${i}"'') rule.from;
      toSet = lib.concatMapStringsSep ", " (i: ''"${i}"'') rule.to;
    in "    iifname { ${fromSet} } oifname { ${toSet} } accept") cfg.forwardRules;

    masqueradeEntries = lib.concatMapStringsSep "\n" (rule: let
      fromSet = lib.concatMapStringsSep ", " (i: ''"${i}"'') rule.from;
      toSet = lib.concatMapStringsSep ", " (i: ''"${i}"'') rule.to;
    in "    iifname { ${fromSet} } oifname { ${toSet} } masquerade") cfg.masqueradeRules;

    hasMasquerade = cfg.masqueradeRules != [];
    hasForward = cfg.forwardRules != [] || cfg.extraForwardRules != "";

    natTable =
      if hasMasquerade
      then ''

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
        ${masqueradeEntries}
          }
        }
      ''
      else "";

    ruleset = ''
      table inet filter {
      ${chainsText}
        chain input {
          type filter hook input priority 0; policy drop;

          iif lo accept
          ${trustedText}

          ct state established,related accept
          ct state invalid drop

          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept

          ${allInputRules}

          ${tcpAccept}
          ${udpAccept}
        }

        chain forward {
          type filter hook forward priority 0; policy drop;
          ct state established,related accept
          ct state invalid drop
      ${forwardEntries}
          ${cfg.extraForwardRules}
        }

        chain output { type filter hook output priority 0; policy accept; }
      }
      ${natTable}
      ${cfg.extraRules}
    '';
  in {
    networking.firewall.enable = false;
    networking.nftables = {
      enable = true;
      checkRuleset = false;
      inherit ruleset;
    };

    boot.kernel.sysctl = lib.mkIf hasForward {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
