{
  path = ["psyclyx" "nixos" "services" "fail2ban"];
  description = "Fail2ban intrusion prevention";
  config = {config, ...}: {
    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        maxtime = "168h";
        factor = "4";
      };
      jails.sshd.settings = {
        enabled = true;
        port = builtins.concatStringsSep "," (map toString config.services.openssh.ports);
        filter = "sshd[mode=aggressive]";
      };
    };
  };
}
