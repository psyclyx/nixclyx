{ ... }:
{
  psyclyx.nixos.topology = {
    # Project nfs-export entities into services.nfs-server.exports here +
    # fileSystems on each consumer.
    nfs.enable = true;

    # Project lun entities. No iSCSI consumers yet (no VMs spun up), so
    # this is a no-op until LUNs appear.
    iscsi.enable = true;
  };

  # Single-node OpenBao for PKI cert issuance — iyr's openbao-login
  # talks here over the lab VLAN. The full Raft-clustered setup is on
  # hold until lab-1..3 come back online; for now lab-4 runs OpenBao
  # standalone using the existing services/openbao/cluster.nix module.
  #
  # services.openbao.cluster wiring goes here in a follow-up commit.
}
