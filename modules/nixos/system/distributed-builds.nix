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

    builders = {
      lab-1 = {sshHost = "lab-1.${rackZone}"; maxJobs = 54; speedFactor = 7;};
      lab-2 = {sshHost = "lab-2.${rackZone}"; maxJobs = 36; speedFactor = 5;};
      lab-3 = {sshHost = "lab-3.${rackZone}"; maxJobs = 36; speedFactor = 5;};
      lab-4 = {sshHost = "lab-4.${rackZone}"; maxJobs = 54; speedFactor = 7;};
    };

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
    system.activationScripts.nix-builder-key = lib.stringAfter ["users"] ''
      if [ ! -f /root/.ssh/id_ed25519 ]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -C "nix-builder@${host}"
      fi
    '';

    programs.ssh.knownHosts.host-ca = {
      hostNames = ["*"];
      publicKey = nixclyx.keys.ca.host;
      certAuthority = true;
    };

    # HostkeyAlias so host cert principal matches the logical name, not the FQDN
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

    # opt-in: nix build --builders @/etc/nix/remote-builders
    environment.etc."nix/remote-builders".text = let
      lines = lib.mapAttrsToList (name: b:
        "ssh://root@${name} x86_64-linux,i686-linux /root/.ssh/id_ed25519 ${toString b.maxJobs} ${toString b.speedFactor} nixos-test,benchmark,big-parallel,kvm - -"
      ) remoteBuilders;
    in lib.concatStringsSep "\n" lines + "\n";

    psyclyx.nixos.services.openssh.authPrincipals.root =
      lib.mkIf acceptsBuilds ["nix-builder"];
  };
}
