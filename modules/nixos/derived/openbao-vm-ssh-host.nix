# Egregore → SSH host-cert wiring for microvm guests.
#
# Reads `host.openbao.ssh.role` (a ref to an openbao-ssh-cert-role
# entity, kind=host) and on the guest enables
# `services.openbao-vm-ssh-host` with the right sign path + the
# host's natural FQDN as the cert principal.
{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.derived.openbao-vm-ssh-host;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = cfg.enable && hostname != "";

  me = eg.entities.${hostname} or null;
  myBinding = if me == null then null else (me.host.openbao or { }).ssh or null;

  roleEntity =
    if myBinding == null then null
    else eg.entities.${myBinding.role} or null;

  fqdn =
    if myBinding == null then null
    else (me.attrs.fqdns or { }).${myBinding.network} or null;

  guestEnabled = myBinding != null && roleEntity != null && fqdn != null;
in
{
  options.psyclyx.nixos.derived.openbao-vm-ssh-host = {
    enable = lib.mkEnableOption ''
      project host.openbao.ssh bindings into per-guest
      openbao-vm-ssh-host services.
    '';

    vaultAddr = lib.mkOption {
      type = lib.types.str;
      default = "https://10.0.25.1:8200";
      description = "OpenBao endpoint used by the guest's sign request.";
    };

    insecureSkipVerify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Skip server-cert verification (self-signed listener).";
    };
  };

  config = lib.mkIf (enabled && guestEnabled) {
    psyclyx.nixos.services.openbao-vm-ssh-host = {
      enable = true;
      vaultAddr = cfg.vaultAddr;
      insecureSkipVerify = cfg.insecureSkipVerify;
      signPath = roleEntity.attrs.signPath;
      hostFqdn = fqdn;
      ttl = roleEntity.openbao-ssh-cert-role.ttl;
    };
  };
}
