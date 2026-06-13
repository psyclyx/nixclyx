{ lib, pkgs, nixclyx, ... }: {
  imports = [./hardware.nix ./network.nix ./filesystems.nix];

  networking.hostName = "sigil";

  environment.systemPackages = [
    pkgs.audacity
    pkgs.bitwig-studio4
    pkgs.gimp-with-plugins
    pkgs.kicad
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
    # ZFS-on-rpool: pools = ["rpool"] makes the zfs module request
    # encryption credentials in initrd for every encryption root on
    # the pool (today: rpool/persist and rpool/home/psyc). bcachefs
    # impermanence is gone — the @blank rollback for / is wired in
    # filesystems.nix as a stage-1 systemd service.
    filesystems.zfs = {
      enable = true;
      hostId = "8372b94b";
      pools = ["rpool"];
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
      ollama = {
        enable = true;
        host = "0.0.0.0";
        acceleration = "cuda";
        keepAlive = "10m";
        extraEnv.OLLAMA_FLASH_ATTENTION = "0"; # gemma4 FA crashes on Ampere (RTX 3090)
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

  # rpool/home/psyc snapshots: tight, recent-history scratch on the
  # SSD; longer tiered history on the spinner. Source keeps a 1 h
  # rolling window of 5-min snapshots (12) plus one of each higher
  # tier — the tier-marker snapshots only exist so sanoid on the
  # destination has snapshots tagged hourly/daily/weekly/monthly to
  # retain. Without those tags, the destination could only retain
  # frequents.
  services.sanoid = {
    enable = true;
    # frequent snapshots fire on this cadence — sanoid takes at
    # most one per run, so hourly (the default) would only land one
    # 5-min snapshot per hour. Need to run every 5 min for the
    # `frequently = 72` retention to actually fill.
    interval = "*:0/5";

    datasets."rpool/home/psyc" = {
      autosnap = true;
      autoprune = true;
      frequently = 12;       # 1 h × (60 min / 5 min)
      frequent_period = 5;
      hourly = 1;
      daily = 1;
      weekly = 1;
      monthly = 1;
    };

    # syncoid brings snapshots across; sanoid on the destination
    # just prunes per these counts. autosnap=false so the spinner
    # never takes its own snapshots (avoids snapshot divergence
    # between source and dest that breaks incremental sends).
    datasets."bulkpool/backups/home-psyc" = {
      autosnap = false;
      autoprune = true;
      frequently = 288;      # 1 day of 5-min snapshots as overlap
      hourly = 168;          # 1 week
      daily = 30;            # 1 month
      weekly = 8;            # 2 months
      monthly = 12;          # 1 year
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
  };

  users.users.psyc.hashedPasswordFile = "/persist/etc/shadow.psyc";

  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/var/lib/nixos"
        "/var/lib/systemd"
        # WireGuard private key, generated once by wireguard-keygen and
        # persisted so it survives the @blank rollback — otherwise the
        # key regenerates every boot and diverges from the pubkey
        # pinned in egregore (sigil.host.wireguard.publicKey), so the
        # hub never recognises the peer and wg0 stays down. Mode/group
        # match what wireguard-keygen sets (root:systemd-network 0750).
        {
          directory = "/etc/secrets/wireguard";
          mode = "0750";
          group = "systemd-network";
        }
      ];
      files = [
        {file = "/etc/machine-id"; inInitrd = true;}
        # Private host key must be 0600; preservation otherwise
        # chmods the source back to the default (0644) on every
        # boot, and sshd then refuses to load it.
        {file = "/etc/ssh/ssh_host_ed25519_key"; mode = "0600";}
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
        {file = "/etc/krb5.keytab"; mode = "0600";}
      ];
    };
  };

  stylix = {
    image = "${nixclyx.assets}/wallpapers/4x-ppmm-mami.jpg";
    base16Scheme = "${nixclyx.assets}/palettes/4x-ppmm-mami.yaml";
    polarity = "dark";
  };
}
