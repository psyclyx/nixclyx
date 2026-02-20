{
  path = ["psyclyx" "nixos" "services" "kea"];
  description = "Kea DHCPv4 server";
  options = {lib, ...}: {
    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Interfaces to serve DHCPv4 on.";
    };
    subnets = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "Kea subnet4 configuration objects.";
    };
    hooksLibraries = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "Kea hooks-libraries configuration objects.";
    };
  };
  config = {cfg, ...}: {
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        interfaces-config.interfaces = cfg.interfaces;
        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp4.leases";
        };
        valid-lifetime = 3600;
        renew-timer = 900;
        rebind-timer = 1800;
        service-sockets-max-retries = 60;
        service-sockets-retry-wait-time = 5000;
        subnet4 = cfg.subnets;
        hooks-libraries = cfg.hooksLibraries;
      };
    };
  };
}
