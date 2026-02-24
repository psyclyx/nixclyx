{
  path = ["psyclyx" "nixos" "boot" "initrd-ssh"];
  description = "SSH access to initrd for remote disk unlocking";
  options = {lib, ...}: {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "SSH public keys authorized to connect to initrd";
    };

    hostKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
      description = "Paths to SSH host keys for initrd";
    };

    network = {
      netdevs = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = {};
        description = "systemd-networkd netdev units for the initrd";
      };

      networks = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.anything;
        default = {};
        description = "systemd-networkd network units for the initrd";
      };

      kernelModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra kernel modules to include in initrd for networking";
      };
    };
  };
  extraOptions = {lib, ...}: {
    psyclyx.nixos.network.ports.initrd-ssh = lib.mkOption {
      type = lib.types.port;
      default = 8022;
      description = "SSH port to listen on in initrd";
    };
  };
  config = {
    cfg,
    config,
    ...
  }: {
    psyclyx.nixos.boot.initrd-ssh.authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
    boot.initrd = {
      kernelModules = cfg.network.kernelModules;
      systemd.network = {
        enable = true;
        netdevs = cfg.network.netdevs;
        networks = cfg.network.networks;
      };
      network.ssh = {
        enable = true;
        authorizedKeys = cfg.authorizedKeys;
        hostKeys = cfg.hostKeyPaths;
        port = config.psyclyx.nixos.network.ports.initrd-ssh;
      };
    };
  };
}
