{
  path = ["psyclyx" "nixos" "services" "icecream"];
  description = "Icecream (icecc) distributed compilation";
  options = {lib, ...}: {
    scheduler = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this node runs the icecream scheduler.";
    };
    schedulerHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicit scheduler hostname/IP. Uses broadcast discovery if null.";
    };
    noRemote = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Prevent remote jobs from being scheduled on this node.";
    };
    maxJobs = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Maximum parallel compile jobs. Defaults to CPU count.";
    };
    netName = lib.mkOption {
      type = lib.types.str;
      default = "PSYCLYX";
      description = "Icecream network name.";
    };
  };
  config = {cfg, lib, ...}: {
    services.icecream.daemon = {
      enable = true;
      inherit (cfg) schedulerHost netName noRemote;
      maxProcesses = cfg.maxJobs;
      openFirewall = false;
      openBroadcast = false;
    };

    services.icecream.scheduler = lib.mkIf cfg.scheduler {
      enable = true;
      inherit (cfg) netName;
      openFirewall = false;
    };
  };
}
