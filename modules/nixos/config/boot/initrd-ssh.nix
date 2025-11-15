{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;
  cfg = config.psyclyx.boot.initrd-ssh;
  portCfg = config.psyclyx.network.ports.initrd-ssh;
in
{
  options = {
    psyclyx.network.ports.initrd-ssh = mkOption {
      type = types.port;
      default = 8022;
      description = "SSH port to listen on in initrd";
    };

    psyclyx.boot.initrd-ssh = {
      enable = mkEnableOption "SSH access to initrd for remote disk unlocking";

      authorizedKeys = mkOption {
        type = types.listOf types.str;
        description = "SSH public keys authorized to connect to initrd";
      };

      hostKeyPaths = mkOption {
        type = types.listOf types.str;
        default = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
        description = "Paths to SSH host keys for initrd";
      };
    };
  };

  config = mkIf cfg.enable {
    psyclyx.boot.initrd-ssh.authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;

    boot.initrd = {
      systemd.network.enable = true;
      network = {
        flushBeforeStage2 = true;
        ssh = {
          enable = true;
          port = portCfg;
          authorizedKeys = cfg.authorizedKeys;
          hostKeys = cfg.hostKeyPaths;
        };
      };
    };
  };
}
