{ ... }:
{
  security = {
    pam = {
      loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = 1;
        }
      ];

      sshAgentAuth.enable = true;
    };

    rtkit = {
      enable = true;
    };

    sudo = {
      extraConfig = ''
        Defaults        timestamp_timeout=30
      '';
    };
  };
}
