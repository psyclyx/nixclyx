{ config, lib, ... }:
let
  cfg = config.psyclyx.services.openssh;
  ports = config.psyclyx.networking.ports.ssh;
in
{
  options = {
    psyclyx = {
      services = {
        openssh = {
          enable = lib.mkEnableOption "Enable OpenSSH.";
        };
      };

      networking = {
        ports = {
          ssh = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ 22 ];
            description = "Ports for OpenSSH to listen on.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      openssh = {
        enable = true;
        inherit ports;
        settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
  };
}
