# Auto-kinit — keep a human user's Kerberos ticket cache fresh from a
# keytab.
#
# rpc.gssd uses the machine keytab for uid 0 automatically, so root NFS
# access over krb5* is durable with no ticket management. An
# unprivileged uid has no such fallback: accessing a krb5* mount under
# its own uid needs that user's own TGT in /tmp/krb5cc_<uid>, which
# nothing renews on a headless/long-lived workstation.
#
# This module installs a per-user oneshot that kinits from a keytab
# into the user's FILE ccache (the location rpc.gssd probes first) plus
# a timer that re-runs it well inside the ticket lifetime. Generic: no
# fleet entity names, no hardcoded user — the consuming host supplies
# the user → keytab mapping.
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "kerberos-user-ticket"
  ];
  description = "Auto-kinit per-user Kerberos tickets from a keytab";

  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "per-user Kerberos auto-kinit";

      users = lib.mkOption {
        default = { };
        description = ''
          Users whose ticket caches should be kept fresh. Keyed by the
          local account name (must resolve to a configured user so its
          uid/gid are known).
        '';
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                keytab = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Path to a keytab holding this user's key. Read by
                    root only — the kinit runs as root and chowns the
                    resulting ccache to the user. The service is gated
                    on this file existing (ConditionPathExists), so it
                    no-ops cleanly until the keytab is provisioned.
                  '';
                };
                principal = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = ''
                    Principal to kinit. Defaults to the bare account
                    name, which libkrb5 qualifies with the krb5.conf
                    default_realm (`psyc` → `psyc@PSYCLYX.NET`).
                  '';
                };
                renewInterval = lib.mkOption {
                  type = lib.types.str;
                  default = "8h";
                  description = ''
                    Age (systemd timespan) after which a still-valid
                    ccache is re-kinited. Must be comfortably shorter
                    than the ticket lifetime (24h default) so the cache
                    never lapses.
                  '';
                };
                retryInterval = lib.mkOption {
                  type = lib.types.str;
                  default = "5min";
                  description = ''
                    Timer tick. Each tick is a cheap no-op while the
                    ccache is valid and younger than renewInterval, so
                    this is effectively the retry cadence after a failed
                    kinit (KDC unreachable etc.).
                  '';
                };
              };
            }
          )
        );
      };
    };

  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf (cfg.enable && cfg.users != { }) (
      let
        krb5 = pkgs.krb5;
        mkUnitName = user: "kinit-${user}";

        mkService = user: u: {
          name = mkUnitName user;
          value = {
            description = "kinit ${u.principal} for ${user}";
            # rpc.gssd doesn't need to be up for kinit to succeed, but
            # ordering after it means a fresh ticket is in place before
            # the first NFS upcall on boot.
            after = [ "network-online.target" "rpc-gssd.service" ];
            wants = [ "network-online.target" ];
            # Deliberately not wantedBy anything, and not restarted on
            # switch: the timer is the only thing that starts it.
            #
            # switch-to-configuration reports *every* unit that is failed
            # or in auto-restart after activation — not just jobs it ran
            # — and exits non-zero. So a failed kinit must never leave
            # the unit failed: the script warns and exits 0, and the
            # timer's next tick is the retry. No Restart=.
            restartIfChanged = false;
            unitConfig.ConditionPathExists = u.keytab;
            serviceConfig = {
              Type = "oneshot";
              # Keytab is root-only; kinit as root then hand the cache
              # to the user so gssd (which matches ccache owner to the
              # upcall uid) will use it.
              User = "root";
            };
            path = [ krb5 pkgs.coreutils pkgs.gnused pkgs.systemd ];
            # Resolve uid/gid at runtime: a normal account with an
            # auto-allocated uid has `users.users.<u>.uid = null` at
            # eval time, so the ccache path must come from `id`, not the
            # config. FILE ccache /tmp/krb5cc_<uid> is the path rpc.gssd
            # probes before /run/user/<uid> (confirmed via gssd -vvv).
            script = ''
              set -euo pipefail
              uid=$(id -u ${lib.escapeShellArg user})
              gid=$(id -g ${lib.escapeShellArg user})
              ccache="/tmp/krb5cc_''${uid}"
              renew_us=$(systemd-analyze timespan ${lib.escapeShellArg u.renewInterval} \
                | sed -n 's/^ *μs: //p')
              if klist -s -c "$ccache" 2>/dev/null; then
                age_us=$(( ($(date +%s) - $(stat -c %Y "$ccache")) * 1000000 ))
                if (( age_us < renew_us )); then
                  exit 0
                fi
              fi
              if ! kinit -k -t ${lib.escapeShellArg u.keytab} \
                  -c "$ccache" ${lib.escapeShellArg u.principal}; then
                echo "kinit failed; retrying in ${u.retryInterval}" >&2
                exit 0
              fi
              chown "''${uid}:''${gid}" "$ccache"
              chmod 600 "$ccache"
            '';
          };
        };

        mkTimer = user: u: {
          name = mkUnitName user;
          value = {
            description = "Periodic kinit for ${user}";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              # Fires shortly after the timer activates (boot, switch),
              # then every retryInterval; the script decides whether a
              # kinit is actually due.
              OnActiveSec = "5s";
              OnUnitActiveSec = u.retryInterval;
            };
          };
        };
      in
      {
        systemd.services = lib.mapAttrs' mkService cfg.users;
        systemd.timers = lib.mapAttrs' mkTimer cfg.users;
      }
    );
}
