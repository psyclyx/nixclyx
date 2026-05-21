# Lab-loader bootstrap mode — what runs when the chain bails.
#
# The loader's stage-1 unit exits cleanly (without kexec'ing) when:
#   - kernel cmdline is missing pxe-host / pxe-spec-url
#   - the spec endpoint isn't reachable
#   - no system profile exists at the spec's kexecProfile path
#   - the profile resolves to a closure not in /mnt-nix
#
# In any of those cases, the box is reachable on SSH so the operator
# can investigate or run `bootstrap-host <name>` from sigil. SSH host
# key is generated ephemerally per boot — bootstrap-mode hosts are
# inherently TOFU.
{ pkgs, lib, nixclyx, ... }:
let
  authorizedKeysText = lib.concatStringsSep "\n" nixclyx.keys.psyc.openssh;
  authorizedKeys = pkgs.writeText "lab-loader-authorized-keys" authorizedKeysText;
  bootstrapScript = pkgs.writeShellScript "lab-loader-bootstrap-mode" ''
    set -euo pipefail

    HOST=""
    for kv in $(cat /proc/cmdline); do
      case "$kv" in
        pxe-host=*) HOST="''${kv#pxe-host=}";;
      esac
    done
    HOST=''${HOST:-unknown}

    mkdir -p /etc/ssh /root/.ssh
    cp ${authorizedKeys} /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys

    # Ephemeral host key — bootstrap mode is TOFU on purpose.
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
      ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
    fi

    IP=$(ip -4 -o addr show scope global | awk '{print $4}' | head -n1 || echo 'no-ip')

    cat > /etc/issue <<EOF
    ========================================================
    lab-loader bootstrap mode
    --------------------------------------------------------
    host: $HOST
    ip:   $IP

    Cannot proceed automatically — no spec or no profile.

    From sigil:
      ./scripts/bootstrap-host $HOST --format    (fresh install)
      ./scripts/bootstrap-host $HOST --reinstall (skip disko)
      ./scripts/bootstrap-host $HOST --rollback  (pick a generation)

    Or SSH in directly: root@$IP (key: ephemeral, accept-new).
    ========================================================
    EOF

    # systemd in initrd: spawn sshd as a service. Keep it foregrounded
    # so the unit doesn't appear to exit (initrd doesn't auto-cleanup).
    exec ${pkgs.openssh}/bin/sshd -D -p 22 \
      -h /etc/ssh/ssh_host_ed25519_key \
      -o "PermitRootLogin=prohibit-password" \
      -o "PasswordAuthentication=no"
  '';
in
{
  boot.initrd.systemd.services.lab-loader-bootstrap-mode = {
    description = "lab-loader: SSH-reachable bootstrap mode";
    wantedBy = [ "initrd.target" ];
    after = [ "lab-loader-chain.service" ];
    # Hold initrd open — don't let systemd transition to the squashfs
    # stage-2 while we're providing SSH access for the operator.
    conflicts = [
      "initrd-switch-root.target"
      "initrd-switch-root.service"
    ];
    before = [
      "initrd-switch-root.target"
      "initrd-switch-root.service"
    ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${bootstrapScript}";
      Restart = "on-failure";
    };
    unitConfig.DefaultDependencies = false;
  };
}
