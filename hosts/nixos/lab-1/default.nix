{ ... }:
{
  networking.hostName = "lab-1";
  psyclyx.nixos = {
    role = "server";

    # Icecream cluster scheduler for the lab.
    services.icecream.scheduler = true;

    # Egregore projects the lab-1 host entity into networkd:
    # static main-VLAN address from host.addresses.main, lab/storage
    # interfaces declared but unused until the 10G driver story is
    # fixed. defaultNetwork = "main" puts the default route there
    # AND adds eno1 to initrd.interfaces.
    network.topology = {
      enable = true;
      defaultNetwork = "main";
    };
    # Bring the network up in initrd so NFS /nix + /persist mount
    # before stage-2 needs them.
    network.interfaces.initrd = {
      enable = true;
      kernelModules = [ "tg3" ];  # Broadcom NetXtreme on eno1.
    };

    # Accept on lan zone — same convention as lab-4. Without this the
    # default-drop policy refuses SSH from inside the apartment LAN.
    network.firewall.input.lan.policy = "accept";

    # HPE-specific knobs (firmware, drivers).
    hardware.presets.hpe.dl360-gen9.enable = true;

    # Diskless: tmpfs root, NFS /nix + /persist derived from
    # host.refs.{nixDataset,persistDataset} via the storage projection.
    filesystems.nfs-root.enable = true;
  };
}
