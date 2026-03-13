{
  path = ["psyclyx" "nixos" "system" "distributed-builds"];
  description = "Nix distributed build configuration with SSH cert auth.";
  gate = {config, ...}:
    builtins.elem config.psyclyx.nixos.host
    ["lab-1" "lab-2" "lab-3" "lab-4" "sigil" "iyr"];
  config = {
    config,
    lib,
    pkgs,
    nixclyx,
    ...
  }: let
    host = config.psyclyx.nixos.host;
    topo = config.psyclyx.topology;
    dt = topo.enriched;
    rackZone = dt.networks.rack.zoneName;

    # Machines that accept remote builds from others.
    builders = {
      lab-1 = {sshHost = "lab-1.${rackZone}"; maxJobs = 54; speedFactor = 7;};
      lab-2 = {sshHost = "lab-2.${rackZone}"; maxJobs = 36; speedFactor = 5;};
      lab-3 = {sshHost = "lab-3.${rackZone}"; maxJobs = 36; speedFactor = 5;};
      lab-4 = {sshHost = "lab-4.${rackZone}"; maxJobs = 54; speedFactor = 7;};
    };

    # Machines that have the nix-builder account (can accept builds
    # even if not actively listed as a builder target).
    acceptsBuilds = builtins.elem host
      (builtins.attrNames builders ++ ["sigil"]);

    remoteBuilders = lib.filterAttrs (name: _: name != host) builders;

    localMaxJobs = {
      lab-1 = 54;
      lab-2 = 36;
      lab-3 = 36;
      lab-4 = 54;
      sigil = 24;
      iyr = 2;
    };
  in {
    # Generate builder SSH key pair on first boot / redeploy
    system.activationScripts.nix-builder-key = lib.stringAfter ["users"] ''
      if [ ! -f /root/.ssh/id_ed25519 ]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -C "nix-builder@${host}"
      fi
    '';

    # Trust the host CA for outgoing SSH host verification
    programs.ssh.knownHosts.host-ca = {
      hostNames = ["*"];
      publicKey = nixclyx.keys.ca.host;
      certAuthority = true;
    };

    # Map builder short names to FQDNs resolved via DNS.
    # HostkeyAlias ensures host cert principal is checked against
    # the logical name, not the resolved FQDN.
    programs.ssh.extraConfig = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: b: ''
        Host ${name}
          HostName ${b.sshHost}
          HostkeyAlias ${name}
      '') remoteBuilders
    );

    nix = {
      distributedBuilds = false;

      settings = {
        builders-use-substitutes = true;
        max-jobs = lib.mkForce localMaxJobs.${host};
      };
    };

    # Write builder specs to /etc/nix/remote-builders so the user can
    # opt in with:  nix build --builders @/etc/nix/remote-builders
    environment.etc."nix/remote-builders".text = let
      lines = lib.mapAttrsToList (name: b:
        "ssh://root@${name} x86_64-linux,i686-linux /root/.ssh/id_ed25519 ${toString b.maxJobs} ${toString b.speedFactor} nixos-test,benchmark,big-parallel,kvm - -"
      ) remoteBuilders;
    in lib.concatStringsSep "\n" lines + "\n";

    # Machines that accept builds get the nix-builder principal for root SSH
    psyclyx.nixos.services.openssh.authPrincipals.root =
      lib.mkIf acceptsBuilds ["nix-builder"];
  };
}
