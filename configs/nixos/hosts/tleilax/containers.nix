{ ... }:
let
  prefix6 = "2606:7940:32:26::";
in
{
  config = {
    containers = {
      ssh = {
        autoStart = true;
        privateNetwork = false;
        bindMounts."/root" = {
          hostPath = "/var/lib/containers/ssh";
          isReadOnly = false;
        };

        config =
          { config, pkgs, ... }:
          {
            users.users.root = {
              home = "/root";
              openssh.authorizedKeys.keys = [
              ];
            };
            services.openssh = {
              enable = true;
              listenAddresses = [
                {
                  addr = "[${prefix6}80]";
                  port = 13579;
                }
              ];
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
              };
            };
          };
      };
    };
    networking.firewall.allowedTCPPorts = [ 13579 ];
    system.stateVersion = "25.05";
  };
}
