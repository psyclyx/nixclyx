{ config, ... }:
let
  eg = config.psyclyx.egregore;
in
{
  psyclyx.nixos = {
    # NFS shares + iSCSI targets/initiators projected from egregore data.
    topology.nfs.enable = true;
    topology.iscsi.enable = true;

    # Single-node OpenBao for PKI. The Raft cluster has one member;
    # transit-unseal comes from iyr's seal oracle. iyr's openbao-login
    # and tleilax's openbao-cert-publish target this instance on the
    # lab VLAN (10.0.210.14:8200).
    #
    # The transitTokenFile / authPasswordFile paths are sops-managed,
    # so the privclyx layer at hosts/nixos/lab-4.nix fills them in;
    # everything intrinsic to the cluster shape lives here.
    services.openbao = {
      enable = true;
      clusterNodes = [ "lab-4" ];
      dataNetwork = "lab";
      settings.transitAddress =
        "http://${eg.entities.iyr.attrs.addresses.main.ipv4 or "10.0.10.1"}:8200";

      pki = {
        enable = true;
        commonName = "psyclyx Lab CA";
        roles = [
          {
            name = "postgres-server";
            allowedDomains = "psyclyx.net";
          }
        ];
      };
    };
  };
}
