{ ... }:
{
  # lab-4 is both the storage host AND a compute node — it runs the
  # microvm.nix host stack so it can host VMs locally (zvol-backed
  # block devices via virtio, no iSCSI hop for VMs that live on the
  # same physical box).
  #
  # VM definitions land here later via a topology/vms.nix projection
  # that reads `vm` entities from egregore. For now, host is ready;
  # no VMs declared.
  microvm.host.enable = true;

  # Scheduler placeholder:
  #
  # The fleet scheduler (planned in Zig 0.16.0) will live on lab-4
  # too — it owns placement state in /persist, watches host liveness
  # on the lab VLAN, and reassigns VMs across lab-1..4 on failure.
  # Add the systemd service module once the Zig binary is packaged.
}
