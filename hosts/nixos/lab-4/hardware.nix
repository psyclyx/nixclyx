{ ... }:
{
  psyclyx.nixos = {
    hardware.presets.hpe.dl360-gen9.enable = true;

    network = {
      interfaces = {
        # No bond. Lab-4 speaks only over its two 10G NICs. The initrd
        # for netboot has its networking set up by nixpkgs' netboot
        # module; this list ensures the right SFP+ NIC drivers come
        # along for the ride.
        initrd = {
          enable = true;
          kernelModules = [
            "i40e"
            "ixgbe"
            "tg3"
          ];
        };
      };

      topology = {
        enable = true;
        # Default route via the lab VLAN — CRS326 hardware-routes to
        # everywhere else. Storage stays on its own policy table.
        defaultNetwork = "lab";
      };

      firewall.input.lan.policy = "accept";
    };

    role = "server";
  };

  boot.kernel.sysctl."kernel.sched_autogroup_enabled" = 0;
}
