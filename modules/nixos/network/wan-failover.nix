# Active-probe WAN failover — generic NixOS sugar.
#
# Steers internet-bound traffic onto a *primary* uplink while a
# *fallback* default route (held in the main table by some other unit)
# takes over whenever the primary is unhealthy. Does NOT read egregore;
# the host config supplies the interface/table and the fallback is
# whatever already owns the main-table default (on iyr that's Xfinity).
#
# Routing model
# -------------
# The primary uplink installs its default route into a dedicated table
# (`primaryTable`), NOT the main table — set `dhcpV4Config.RouteTable`
# on the primary's networkd unit. The watchdog then owns two IPv4
# policy rules while the primary is healthy:
#
#   pri  N   : lookup main suppress_prefixlength 0
#             -> consult the main table for *specific* routes (connected
#                LAN/VPN/internal subnets keep routing normally) but mask
#                its default route.
#   pri  N+1 : lookup <primaryTable>
#             -> everything the main table didn't match (i.e. the
#                internet-bound default) egresses the primary.
#
# When the primary is unhealthy the watchdog removes both rules, so
# lookups hit the main table normally and internet traffic follows the
# fallback default. The suppress rule is what makes this safe: without
# it a bare `lookup <primaryTable>` rule would shadow the whole main
# table and blackhole internal traffic onto the primary's default.
#
# Two independent failover paths result, and the safe state is always
# the fallback:
#   * primary link down  — networkd withdraws the primary default from
#     `primaryTable`, so even with the rules present, rule N+1 finds no
#     route and lookup falls through to the main-table default.
#   * primary internet down behind a live link — the watchdog's probes
#     fail and it removes the rules.
#   * watchdog/service dead — no rules at all -> plain main-table
#     routing -> fallback. Correct internal routing either way.
#
# The probe is source-bound to the primary interface (`ping -I`), so it
# tests the primary's real path regardless of which uplink currently
# holds the selected default. On iyr that bound socket reaches the
# primary via the diagnostic oif rule on the primary's networkd unit.
{
  path = ["psyclyx" "nixos" "network" "wan-failover"];
  description = "Active-probe WAN failover (policy-routing primary select)";
  options = { lib, ... }: {
    primaryInterface = lib.mkOption {
      type = lib.types.str;
      description = "Interface of the preferred uplink to probe and steer onto.";
    };
    primaryTable = lib.mkOption {
      type = lib.types.int;
      description = "Routing table holding the primary uplink's default route.";
    };
    rulePriority = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = ''
        Priority of the suppress rule; the primary-select rule sits at
        rulePriority + 1. Both must be below the main-table rule (32766).
      '';
    };
    probeTargets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "1.1.1.1" "8.8.8.8" ];
      description = "Hosts pinged through the primary; any reply = healthy.";
    };
    probeInterval = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds between probe cycles.";
    };
    probeTimeout = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Per-target ping timeout (seconds).";
    };
    failThreshold = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Consecutive failed cycles before failing over to the fallback.";
    };
    recoverThreshold = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Consecutive healthy cycles before failing back to the primary.";
    };
    flushConntrack = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Flush the conntrack table on each failover/failback so
        established flows re-NAT onto the now-selected uplink instead of
        black-holing on the old source address.
      '';
    };
  };
  config = { cfg, lib, pkgs, ... }: {
    # Multi-WAN return paths are asymmetric (a probe reply can arrive on
    # the primary while the selected default points at the fallback, and
    # vice-versa). Strict reverse-path filtering would drop those and
    # wedge the probe; loose mode (2) keeps anti-spoofing without it.
    boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = lib.mkDefault 2;
    boot.kernel.sysctl."net.ipv4.conf.default.rp_filter" = lib.mkDefault 2;

    # The watchdog's steering rules are foreign to networkd. By default
    # networkd purges foreign policy rules on every reload/reconfigure,
    # which would drop the primary uplink until the watchdog re-asserts —
    # an outage on every deploy. Leave foreign rules alone so the rules
    # (and thus the selected uplink) survive networkd reloads.
    systemd.network.config.networkConfig.ManageForeignRoutingPolicyRules = "no";

    systemd.services.wan-failover = {
      description = "Active-probe WAN failover for ${cfg.primaryInterface}";
      after = [ "systemd-networkd.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.iproute2 pkgs.iputils ]
        ++ lib.optional cfg.flushConntrack pkgs.conntrack-tools;
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
      };
      script = let
        psup = toString cfg.rulePriority;
        psel = toString (cfg.rulePriority + 1);
        tbl = toString cfg.primaryTable;
        flush = lib.optionalString cfg.flushConntrack "conntrack -F 2>/dev/null || true";
      in ''
        set -u

        del_rules() {
          while ip -4 rule del priority ${psup} 2>/dev/null; do :; done
          while ip -4 rule del priority ${psel} 2>/dev/null; do :; done
        }
        add_rules() {
          ip -4 rule show | grep -q "^${psup}:" \
            || ip -4 rule add priority ${psup} table main suppress_prefixlength 0
          ip -4 rule show | grep -q "^${psel}:" \
            || ip -4 rule add priority ${psel} table ${tbl}
        }
        probe() {
          for t in ${lib.concatStringsSep " " cfg.probeTargets}; do
            ping -n -q -I ${cfg.primaryInterface} -c 1 -W ${toString cfg.probeTimeout} "$t" \
              >/dev/null 2>&1 && return 0
          done
          return 1
        }

        # Don't tear rules down on start. If the primary was healthy
        # before a restart, its rules are still in place (preserved
        # across networkd reloads via ManageForeignRoutingPolicyRules=no),
        # so leave them and keep steering with no gap. Reconcile toward
        # the probed state below; the main-table default carries traffic
        # in the meantime either way.
        up=0; down=0; state=unknown

        while true; do
          if probe; then up=$((up + 1)); down=0; else down=$((down + 1)); up=0; fi

          if [ "$up" -ge ${toString cfg.recoverThreshold} ] && [ "$state" != up ]; then
            add_rules; ${flush}; state=up
            echo "primary ${cfg.primaryInterface} healthy -> steering internet via table ${tbl}"
          elif [ "$down" -ge ${toString cfg.failThreshold} ] && [ "$state" != down ]; then
            del_rules; ${flush}; state=down
            echo "primary ${cfg.primaryInterface} down -> falling back to main-table default"
          elif [ "$state" = up ]; then
            # Re-assert idempotently in case the rules were purged.
            add_rules
          fi

          sleep ${toString cfg.probeInterval}
        done
      '';
    };
  };
}
