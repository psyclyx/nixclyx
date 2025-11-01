{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.boot.initrd-ssh;
in
{
  options = {
    psyclyx.boot.initrd-ssh = {
      enable = lib.mkEnableOption "SSH access to initrd for remote disk unlocking";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8022;
        description = "SSH port to listen on in initrd";
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = inputs.self.common.keys.psyc.openssh;
        description = "SSH public keys authorized to connect to initrd";
      };

      hostKeyPath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/secrets/initrd/ssh_host_key";
        description = "Path to the SSH host key for initrd";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd = {
      network = {
        enable = true;
        udhcpc.enable = true;
        flushBeforeStage2 = true;

        ssh = {
          enable = true;
          port = cfg.port;
          authorizedKeys = cfg.authorizedKeys;
          hostKeys = [ cfg.hostKeyPath ];
        };

        postCommands = ''
          # Automatically ask for the password on SSH login
          echo 'cryptsetup-askpass || echo "Unlock was successful; exiting SSH session" && exit 1' >> /root/.profile
        '';
      };
    };
  };
}
