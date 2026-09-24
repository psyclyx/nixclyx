# Global configuration values for the psyclyx fleet.
{
  gate = "always";
  config = {
    conventions = {
      gatewayOffset = 1;
      # Everything we number out of is inside 10/8.
      internalPrefixes = [ "10.0.0.0/8" ];
      transitVlan = 250;
      adminSshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPK+1GlLeOjyDZjcdGFXjDnJfgtO7OOOoeTliAwZRSsf psyc@sigil"
      ];
    };

    domains = {
      internal = "psyclyx.net";
      public   = "psyclyx.xyz";
    };

    ipv6UlaPrefix = "fd9a:e830:4b1e";

    iscsi = {
      baseIqn = "iqn.2026-05.net.psyclyx";
    };

    openbao = {
      serverHost = "iyr";
      serverNetwork = "infra";
      port = 8200;
      scheme = "https";
    };

    # Kerberos realm — declared here so client modules know the
    # realm name. `primary` is null until the KDC is provisioned:
    # the projection in derived/kerberos.nix only enables the KDC
    # service on a host once `primary` names it AND the host's
    # NixOS config supplies the stash-file sops secret. See
    # (see the one-time provisioning ritual in ops notes).
    kerberos = {
      realm = "PSYCLYX.NET";
      primary = "tleilax";
      # secondaries = [ "iyr" ];   # add after iyr stash secret is wired
      kdcNetwork = "vpn";
      domainRealmMappings = {
        "psyclyx.net" = "PSYCLYX.NET";
        ".psyclyx.net" = "PSYCLYX.NET";
      };
      # Human principal for browsing the krb5i lab-4 NAS mount as
      # `psyc` (uid 1000) on sigil — root uses the machine keytab, but
      # an unprivileged uid needs its own ticket. The KDC mints
      # psyc@PSYCLYX.NET + pushes the keytab to OpenBao; sigil pulls it
      # and auto-kinits (see hosts/nixos/sigil + kerberos user-ticket).
      userPrincipals = [ "psyc" ];
    };

    # Policy zones. A zone groups networks that share forward-policy
    # treatment. Networks join zones via `network.zone`. Zone names
    # live in globals (not the entity registry) so we don't have to
    # dodge collisions with networks/hosts of the same conceptual
    # name (e.g. `storage` is both a network and a zone).
    zones = {
      lan.label = "Apartment LAN — workstations, sigil, trusted humans.";
      infra.label = "Apt infra services — control plane, VIPs.";
      mgmt.label = "Out-of-band management — iLO/IPMI/BMC.";
      storage.label = "Rack-internal storage fabric — unauthenticated NFS/iSCSI.";
      lab-transit.label = "Hypervisor↔mdf-agg01 routed transit.";
      core-transit.label = "iyr↔mdf-agg01 router-on-a-stick transit (NAT hairpin).";
      wg.label = "WireGuard overlay — site-to-site + road warriors.";
      wan.label = "Internet transit.";
    };

    # Forward-policy matrix. Read as `policy.<src-zone>.<dst-zone>` →
    # action. Default for any unspecified pair is implicit drop.
    # See zones.nix for the zone map; new zones go there
    # and pick up their policy here.
    policy = {
      # Everything mdf-agg01 routes, arriving at iyr over the transit
      # link. The switch hardware-routes east-west and hands north-south
      # here, so these packets are not the switch's own traffic — they
      # carry the original client's source address, from any VLAN behind
      # the switch. The zone therefore inherits what those clients are
      # allowed, and the destination zones below grant it in return.
      #
      # KNOWN WRONG, do not trust this zone to restrict anything: the
      # rules derived from it match on iifname, and every switch-routed
      # source arrives on the same interface. `wan = accept` here grants
      # WAN to every VLAN behind the switch, including storage, whose own
      # row below says it has none. Enforcing this needs source-prefix
      # matching at iyr, not zones.
      core-transit = {
        wan = "accept";           # north-south NAT, the whole point
        infra = "accept";         # DNS, NTP, OpenBao
        mgmt = "accept";          # iLO from behind the switch
        wg = "accept";
      };

      # apt-LAN traffic: trusted users reach everything except the
      # storage-internal fabric, which is rack-only.
      lan = {
        core-transit = "accept";  # replies to switch-routed clients
        lan = "accept";           # hairpin: clients reaching mdf-agg01 via iyr
        infra = "accept";
        lab-transit = "accept";   # SSH to hypervisors
        storage = "accept";       # admin path into rack-internal hosts
        mgmt = "accept";          # iLO/IPMI from workstations
        wg = "accept";            # reach overlay peers
        wan = "accept";           # internet
      };

      # Infra services talk to each other and out for updates.
      infra = {
        core-transit = "accept";  # replies to switch-routed clients
        infra = "accept";
        lan = "accept";
        wan = "accept";
        storage = "accept";
        wg = "accept";
      };

      # WG overlay: tleilax + road warriors + apt peers. tleilax is
      # the ingress origin for apt-side services.
      wg = {
        lan = "accept";
        infra = "accept";
        wg = "accept";
        storage = "accept";
        lab-transit = "accept";
      };

      # Lab-transit: hypervisor canonical identity; can reach
      # everything else from the host kernel.
      lab-transit = {
        lan = "accept";
        infra = "accept";
        wg = "accept";
        wan = "accept";
        storage = "accept";
      };

      # Storage VLAN: rack-internal, unauth NFS/iSCSI. Admin SSH path
      # in from lan/wg per the doc; no outbound to anywhere else.
      storage = {
        lan = "accept";       # SSH replies to admin
        wg = "accept";
        lab-transit = "accept";
        # No wan, no infra outbound — storage hosts don't initiate
        # connections off the rack. Not currently enforced; see the
        # core-transit note above.
      };




      # mgmt: out-of-band. Reachable from lan/wg only; no outbound.
      mgmt = { };
    };
  };
}
