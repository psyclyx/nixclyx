# Global configuration values for the psyclyx fleet.
{
  gate = "always";
  config = {
    conventions = {
      gatewayOffset = 1;
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
    # docs/lab-v3.md for the one-time provisioning ritual.
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
      guest.label = "Guest WiFi — internet-only, no LAN access.";
      iot.label = "IoT devices — isolated, limited internet.";
      mgmt.label = "Out-of-band management — iLO/IPMI/BMC.";
      storage.label = "Rack-internal storage fabric — unauthenticated NFS/iSCSI.";
      lab-transit.label = "Hypervisor↔mdf-agg01 routed transit; BGP backbone.";
      cluster-workload.label = "Cluster prod + stage VMs — ingress-served, no WAN.";
      cluster-scratch.label = "Cluster scratch VMs — playground; WAN allowed.";
      cluster-orch.label = "Cluster orchestration control plane.";
      wg.label = "WireGuard overlay — site-to-site + road warriors.";
      wan.label = "Internet transit.";
    };

    # Forward-policy matrix. Read as `policy.<src-zone>.<dst-zone>` →
    # action. Default for any unspecified pair is implicit drop.
    # See docs/lab-v3.md for the rationale; new zones go in zones.nix
    # and pick up their policy here.
    policy = {
      # apt-LAN traffic: trusted users reach everything except the
      # storage-internal fabric (which is rack-only) and the cluster
      # workloads' L2 (clients reach those via ingress, not directly).
      lan = {
        lan = "accept";           # hairpin: clients reaching mdf-agg01 via iyr
        infra = "accept";
        lab-transit = "accept";   # SSH to hypervisors
        storage = "accept";       # admin path into rack-internal hosts
        mgmt = "accept";          # iLO/IPMI from workstations
        wg = "accept";            # reach overlay peers
        wan = "accept";           # internet
        cluster-workload = "accept";  # NFS (sigil-fast-path) + admin
        cluster-scratch = "accept";
        cluster-orch = "accept";
      };

      # Infra services talk to each other and out for updates.
      infra = {
        infra = "accept";
        lan = "accept";
        wan = "accept";
        storage = "accept";
        wg = "accept";
      };

      # WG overlay: tleilax + road warriors + apt peers. tleilax is
      # the ingress origin for cluster-workload.
      wg = {
        lan = "accept";
        infra = "accept";
        wg = "accept";
        storage = "accept";
        lab-transit = "accept";
        cluster-workload = "accept";  # ingress from tleilax HAProxy
        cluster-orch = "accept";
      };

      # Lab-transit: hypervisor canonical identity; can reach
      # everything else from the host kernel.
      lab-transit = {
        lan = "accept";
        infra = "accept";
        wg = "accept";
        wan = "accept";
        storage = "accept";
        cluster-workload = "accept";
        cluster-scratch = "accept";
        cluster-orch = "accept";
      };

      # Storage VLAN: rack-internal, unauth NFS/iSCSI. Admin SSH path
      # in from lan/wg per the doc; no outbound to anywhere else.
      storage = {
        lan = "accept";       # SSH replies to admin
        wg = "accept";
        lab-transit = "accept";
        # No wan, no cluster, no infra outbound — storage hosts don't
        # initiate connections off the rack.
      };

      # Cluster workload (prod+stage): no WAN, no scratch/orch peering
      # for now (revisit if orch needs to push to workload).
      cluster-workload = {
        wg = "accept";              # serve ingress
        lan = "accept";             # serve sigil-NFS, admin
        lab-transit = "accept";     # hypervisor services (KDC, etc.)
        cluster-workload = "accept"; # prod↔stage and intra-env
      };

      # Cluster scratch: WAN-allowed playground.
      cluster-scratch = {
        wan = "accept";
        wg = "accept";
        lan = "accept";
        lab-transit = "accept";
        cluster-scratch = "accept";
      };

      # Cluster orch: scheduler reach into workloads + reach to lan/wg
      # for ops. No direct WAN by default.
      cluster-orch = {
        cluster-workload = "accept";
        cluster-scratch = "accept";
        lab-transit = "accept";
        lan = "accept";
        wg = "accept";
        infra = "accept";
        cluster-orch = "accept";
      };

      # Guest / IoT: internet-only.
      guest = {
        wan = "accept";
      };
      iot = {
        wan = "accept";
      };

      # mgmt: out-of-band. Reachable from lan/wg only; no outbound.
      mgmt = { };
    };
  };
}
