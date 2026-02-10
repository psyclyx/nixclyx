{
  path = ["psyclyx" "nixos" "network" "bonds"];
  description = "LACP bond interfaces via systemd-networkd";
  gate = {cfg, ...}: cfg != {};
  options = {lib, ...}:
    lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.str;
            default = "802.3ad";
            description = "Bond mode.";
          };
          lacpRate = lib.mkOption {
            type = lib.types.enum ["fast" "slow"];
            default = "fast";
            description = "LACP transmit rate.";
          };
          hashPolicy = lib.mkOption {
            type = lib.types.str;
            default = "layer3+4";
            description = "Transmit hash policy.";
          };
          miiMonitorSec = lib.mkOption {
            type = lib.types.str;
            default = "100ms";
            description = "MII link monitoring interval.";
          };
          ports = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Interface names/globs for bond member ports.";
          };
          network = lib.mkOption {
            type = lib.types.attrs;
            default = {};
            description = "Raw attrs merged into the bond's systemd network unit.";
          };
        };
      });
      default = {};
      description = "Bond interface definitions.";
    };
  config = {cfg, lib, ...}: {
    systemd.network = lib.mkMerge (lib.mapAttrsToList (name: bondCfg: lib.mkMerge [
      {
        netdevs."10-${name}" = {
          netdevConfig = {
            Name = name;
            Kind = "bond";
          };
          bondConfig = {
            Mode = bondCfg.mode;
            LACPTransmitRate = bondCfg.lacpRate;
            TransmitHashPolicy = bondCfg.hashPolicy;
            MIIMonitorSec = bondCfg.miiMonitorSec;
          };
        };
        networks."30-${name}-ports" = {
          matchConfig.Name = builtins.concatStringsSep " " bondCfg.ports;
          networkConfig.Bond = name;
        };
        networks."40-${name}" = lib.recursiveUpdate {
          matchConfig.Name = name;
          linkConfig.RequiredForOnline = "routable";
        } bondCfg.network;
      }
    ]) cfg);
  };
}
