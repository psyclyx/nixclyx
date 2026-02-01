{...}: {
  config = {
    networking.hostName = "vigil";

    psyclyx = {
      nixos = {
        boot = {
          initrd-ssh.enable = true;
        };

        filesystems.layouts.bcachefs-pool = {
          enable = true;
          UUID = {
            root = "0b6d93c8-c6d3-4243-9413-25543a093c65";
            boot = "0289-61AC";
          };
        };

        hardware = {
          cpu.intel.enable = true;
        };

        roles = {
          base.enable = true;
          remote.enable = true;
          utility.enable = true;
        };

        users.psyc = {
          enable = true;
          server = true;
        };
      };
    };
  };
}
