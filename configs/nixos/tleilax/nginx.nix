{ pkgs, ... }:
{
  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  services.nginx.virtualHosts."tleilax.psyclyx.xyz" = {
    addSSL = true;
    enableACME = true;
    root = "/var/www/psyclyx.xyz";
  };

  services.nginx.virtualHosts."codex.staging.psyclyx.xyz" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:12673";
      proxyWebsockets = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "me@psyclyx.xyz";
  };

  environment.etc = {
    "fail2ban/filter.d/nginx-url-probe.local".text = pkgs.lib.mkDefault (
      pkgs.lib.mkAfter ''
        [Definition]
        failregex = ^<HOST>.*(GET /(wp-|admin|boaform|phpmyadmin|\.env|\.git)|\.(dll|so|cfm|asp)|(\?|&)(=PHPB8B5F2A0-3C92-11d3-A3A9-4C7B08C10000|=PHPE9568F36-D428-11d2-A769-00AA001ACF42|=PHPE9568F35-D428-11d2-A769-00AA001ACF42|=PHPE9568F34-D428-11d2-A769-00AA001ACF42)|\\x[0-9a-zA-Z]{2})
      ''
    );
  };

  services.fail2ban.jails = {
    ngnix-url-probe.settings = {
      enabled = true;
      filter = "nginx-url-probe";
      logpath = "/var/log/nginx/access.log";
      action = ''%(action_)s[blocktype=DROP] '';
      backend = "auto";
      maxretry = 5;
      findtime = 600;
    };
  };
}
