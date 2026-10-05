{
  lib,
  pkgs,
  nixclyx,
  ...
}: {
  imports = [./hardware.nix ./network.nix ./filesystems.nix];

  networking.hostName = "sigil";

  environment.systemPackages = [
    pkgs.audacity
    pkgs.bitwig-studio4
    pkgs.gimp-with-plugins
    pkgs.kicad
    (pkgs.zoom-us.override {wlrXdgDesktopPortalSupport = true;})
  ];

  # home-manager activation runs as a user systemd service with
  # `RequiresMountsFor=%h`, so it waits until pam_zfs_key has mounted
  # /home/<user> before doing anything. Without this, system-level HM
  # activation fires during nixos-rebuild boot — long before login —
  # and writes its symlinks into the underlay (rpool/ROOT/nixos at
  # /home/psyc), which impermanence then wipes on the next boot.
  # See filesystems.nix for the PAM/ZFS contract this depends on.
  home-manager.startAsUserService = true;

  # The rsync migration brought over real files that HM wants to
  # manage as /nix/store-pointing symlinks (Firefox's profiles.ini,
  # mimeapps.list, etc.). Without this, HM activation refuses to
  # touch any conflicting file and aborts the whole switch — leaving
  # half-activated state with missing .zshrc / .bashrc / dotfiles.
  # With backupFileExtension set, HM renames conflicts to
  # `<file>.hm-backup` and writes its own symlink in their place.
  # Reviewable after activation: `find /home/psyc -name '*.hm-backup'`.
  home-manager.backupFileExtension = "hm-backup";

  psyclyx.nixos = {
    # Pools, data pools, and the initrd encryption roots are all derived
    # from the zfs-pool / zfs-dataset entities in
    # configs/egregore/storage/sigil.nix by derived/storage.nix — see
    # filesystems.nix. Only hostId (a host fact, not fleet data) is set
    # here. bcachefs impermanence is gone — the @blank rollback for / is
    # wired in filesystems.nix as a stage-1 systemd service.
    filesystems.zfs = {
      enable = true;
      hostId = "8372b94b";
      encryption.enable = true;
    };

    programs = {
      glasgow.enable = true;
      orca-slicer.enable = true;
      steam.enable = true;
    };

    network = {
      dns.client.enable = true;
      firewall = {
        zones.lan.interfaces = ["br0" "wg0"];
        input.lan.policy = "accept";
      };
    };

    role = "workstation";

    services = {
      openrgb.enable = true;
      icecream = {
        enable = true;
        schedulerHost = "10.0.25.11"; # lab-1 via WireGuard
        noRemote = true;
      };
      # Keep psyc's TGT fresh so browsing the krb5i /mnt/nas export
      # works under our own uid (root already works via the machine
      # keytab). Keytab pulled out-of-band from OpenBao like the host
      # keytab below, into a persisted root-only file.
      kerberos-user-ticket = {
        enable = true;
        users.psyc.keytab = "/etc/krb5-psyc.keytab";
      };
    };

    system = {
      emulation.enable = true;
      swap.swappiness = 5;
    };
  };

  # Park nix build trees on the scratchpool (own SSD) instead of
  # under /tmp. Multi-user Nix routes user invocations through the
  # daemon, so the daemon's build-dir covers ad-hoc `nix build` from
  # the shell as well.
  nix.settings.build-dir = "/build";

  # psyc's home datasets (rpool/home/psyc, altpool/home/psyc): short
  # history on the NVMe, the rest on the spinner. Source keeps 5-min
  # snapshots for 1 h and hourlies for 1 d, nothing longer.
  #
  # sanoid can only retain a tier on the destination if the source
  # tagged snapshots with it, so the source also takes `daily = 1` for
  # bulkpool's dailies. That's free: the 24 hourlies already pin the
  # same day of churn. Weekly/monthly are deliberately absent — a
  # single source-side weekly or monthly marker pins up to 7 / 31 days
  # of deleted data on rpool (one weekly once held 284G there).
  #
  # sanoid counts are age-based ("hourly = 24" = drop hourlies older
  # than 24 h), and 0 prunes the tier outright. Every tier is set
  # explicitly; unset ones fall back to sanoid's defaults (hourly 48,
  # daily 90, …), and frequent_period defaults to 15, not 5.
  services.sanoid = let
    source = {
      autosnap = true;
      autoprune = true;
      frequently = 12; # 1 h × (60 min / 5 min)
      frequent_period = 5;
      hourly = 24;
      daily = 1;
      weekly = 0;
      monthly = 0;
    };

    # syncoid brings snapshots across; sanoid on the destination
    # just prunes per these counts. autosnap=false so the spinner
    # never takes its own snapshots (avoids snapshot divergence
    # between source and dest that breaks incremental sends).
    # Frequents ride along on every send and are dropped here — the
    # last hour is the source's job. syncoid's own syncoid_* sync
    # snapshot isn't a sanoid tier, so pruning never eats the
    # incremental base.
    backup = {
      autosnap = false;
      autoprune = true;
      frequently = 0;
      hourly = 48;
      daily = 14;
      weekly = 0;
      monthly = 0;
    };
  in {
    enable = true;
    # frequent snapshots fire on this cadence — sanoid takes at
    # most one per run, so hourly (the default) would only land one
    # 5-min snapshot per hour.
    interval = "*:0/5";

    datasets = {
      "rpool/home/psyc" = source;
      "altpool/home/psyc" = source;
      "bulkpool/backups/home-psyc" = backup;
      "bulkpool/backups/altpool-home-psyc" = backup;
    };
  };

  # Raw send (-w) keeps the destination encrypted with the same
  # wrapping key as the source; the backup is never decrypted at
  # rest on the spinner. Hourly cadence matches the user's
  # write-frequency expectations for a workstation home dir; if a
  # delete happens between syncoid runs, sanoid's source-side 5-min
  # snapshots cover the gap.
  services.syncoid = {
    enable = true;
    interval = "hourly";
    commands."home-psyc" = {
      source = "rpool/home/psyc";
      target = "bulkpool/backups/home-psyc";
      sendOptions = "w";
    };
    commands."altpool-home-psyc" = {
      source = "altpool/home/psyc";
      target = "bulkpool/backups/altpool-home-psyc";
      sendOptions = "w";
    };
  };

  # altpool/home/psyc is mounted inside /home/psyc, and pam_zfs_key's
  # instances unmount in the same order they mount: at last logout the
  # rpool instance would try /home/psyc first, hit EBUSY on the nested
  # mount, and leave it mounted anyway. Keep both mounted (and their
  # keys loaded) until shutdown instead.
  security.pam.zfs.noUnmount = true;

  users.users.psyc.hashedPasswordFile = "/persist/etc/shadow.psyc";

  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/var/lib/nixos"
        "/var/lib/systemd"
        # Clock drift calibration; without it chronyd re-learns the
        # oscillator's frequency error from scratch every boot.
        {
          directory = "/var/lib/chrony";
          user = "chrony";
          group = "chrony";
          mode = "0750";
        }
        # Per-user GDM state: last selected session (users/<name>) and
        # avatar (icons/).
        {
          directory = "/var/lib/AccountsService";
          mode = "0775";
        }
        # WireGuard private key, generated once by wireguard-keygen and
        # persisted so it survives the @blank rollback — otherwise the
        # key regenerates every boot and diverges from the pubkey
        # pinned in egregore (sigil.wireguard.publicKey), so the
        # hub never recognises the peer and wg0 stays down. Mode/group
        # match what wireguard-keygen sets (root:systemd-network 0750).
        {
          directory = "/etc/secrets/wireguard";
          mode = "0750";
          group = "systemd-network";
        }
      ];
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
        # Private host key must be 0600; preservation otherwise
        # chmods the source back to the default (0644) on every
        # boot, and sshd then refuses to load it.
        {
          file = "/etc/ssh/ssh_host_ed25519_key";
          mode = "0600";
        }
        "/etc/ssh/ssh_host_ed25519_key.pub"
        # krb5 host keytab for the lab-4 NAS krb5i mount. The tleilax
        # KDC mints host/sigil.main.apt.psyclyx.net (it auto-provisions
        # a principal for every krb NFS consumer) and the keytab is
        # pulled out-of-band into /etc/krb5.keytab. Persist it so it
        # survives the @blank root rollback — without this, rpc-gssd's
        # ConditionPathExists=/etc/krb5.keytab is unmet every boot and
        # the mount fails. The key is stable (KDC re-exports with
        # `ktadd -norandkey`); if the KDC DB is ever rebuilt, re-pull
        # and overwrite /persist/etc/krb5.keytab.
        {
          file = "/etc/krb5.keytab";
          mode = "0600";
        }
        # psyc@PSYCLYX.NET user keytab for the krb5i NAS mount under
        # our own uid — the KDC mints psyc (globals.kerberos
        # .userPrincipals) and pushes its keytab to OpenBao; pulled
        # out-of-band here like the host keytab and consumed by the
        # kerberos-user-ticket auto-kinit service. Persist so it
        # survives the @blank rollback. Re-pull if the KDC DB is rebuilt.
        {
          file = "/etc/krb5-psyc.keytab";
          mode = "0600";
        }
      ];
    };
  };

  stylix = {
    image = "${nixclyx.assets}/wallpapers/4x-ppmm-city-night.jpg";
    base16Scheme = "${nixclyx.assets}/palettes/4x-ppmm-city-night.yaml";
    polarity = "dark";
  };
}
