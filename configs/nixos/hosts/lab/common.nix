{
  inputs,
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;

  psyclyx = inputs.self;
in
{
  imports = [
    psyclyx.nixosModules.psyclyx
  ];

  config = {

    boot = {
      initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
        "sg"
      ];
    };

    environment.systemPackages = [ psyclyx.packages.${pkgs.system}.ssacli ];

    networking.domain = "rack.home.psyclyx.net";

    psyclyx = {
      hardware = {
        cpu.enableMitigations = false;
      };

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      services = {
        locate.users = [ "psyc" ];
      };

      system = {
        containers.enable = true;
        virtualization.enable = true;
      };
    };

    nix.settings.trusted-users = [ "psyc" ];

    users = {
      users = {
        psyc = {
          name = "psyc";
          home = "/home/psyc";
          shell = pkgs.zsh;
          isNormalUser = true;

          extraGroups = [
            "wheel"
            "builders"
          ];

          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz"
          ];
        };
      };
    };

    home-manager.users.psyc = {
      imports = [ ../../../home/psyc.nix ];

      psyclyx.configs.psyc = {
        enable = true;
        server = true;
      };
    };
  };

}
