# CAKE traffic shaping with autorate bandwidth adjustment.
{
  path = ["psyclyx" "nixos" "network" "cake-qos"];
  description = "CAKE QoS traffic shaping with autorate";
  options = { lib, ... }: {
    interface = lib.mkOption {
      type = lib.types.str;
      description = "WAN-facing interface to shape.";
    };
    download = {
      min = lib.mkOption { type = lib.types.int; description = "Minimum download rate (kbps)."; };
      base = lib.mkOption { type = lib.types.int; description = "Baseline download rate (kbps)."; };
      max = lib.mkOption { type = lib.types.int; description = "Maximum download rate (kbps)."; };
    };
    upload = {
      min = lib.mkOption { type = lib.types.int; description = "Minimum upload rate (kbps)."; };
      base = lib.mkOption { type = lib.types.int; description = "Baseline upload rate (kbps)."; };
      max = lib.mkOption { type = lib.types.int; description = "Maximum upload rate (kbps)."; };
    };
    autorate = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable cake-autorate dynamic bandwidth adjustment.";
      };
      version = lib.mkOption {
        type = lib.types.str;
        default = "3.2.2";
      };
      hash = lib.mkOption {
        type = lib.types.str;
        default = "sha256-2WnMmilrVgVwjHK5ZkoXrzVlofuvvwQbSROfvd4RbEk=";
      };
      connectionActiveThr = lib.mkOption {
        type = lib.types.int;
        default = 5000;
        description = "Connection active threshold (kbps).";
      };
    };
  };
  config = { cfg, lib, pkgs, ... }: let
    iface = cfg.interface;
    ifbDev = "ifb-${builtins.replaceStrings ["."] ["-"] iface}";

    cakeAutorate = pkgs.stdenvNoCC.mkDerivation {
      pname = "cake-autorate";
      version = cfg.autorate.version;
      src = pkgs.fetchFromGitHub {
        owner = "lynxthecat";
        repo = "cake-autorate";
        rev = "v${cfg.autorate.version}";
        hash = cfg.autorate.hash;
      };
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/lib/cake-autorate
        cp cake-autorate.sh lib.sh defaults.sh $out/lib/cake-autorate/
        chmod +x $out/lib/cake-autorate/cake-autorate.sh
      '';
    };
  in {
    boot.kernelModules = ["sch_cake" "ifb"];

    systemd.services.cake-qos = {
      description = "CAKE traffic shaping on ${iface}";
      after = [
        "systemd-networkd.service"
        "sys-subsystem-net-devices-${iface}.device"
      ];
      requires = ["sys-subsystem-net-devices-${iface}.device"];
      bindsTo = ["sys-subsystem-net-devices-${iface}.device"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.iproute2];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        tc qdisc replace dev ${iface} root cake \
          bandwidth ${toString cfg.upload.base}kbit \
          diffserv4 nat docsis ack-filter split-gso
        ip link add ${ifbDev} type ifb 2>/dev/null || true
        ip link set ${ifbDev} up
        tc qdisc replace dev ${iface} handle ffff: ingress
        tc filter replace dev ${iface} parent ffff: matchall \
          action mirred egress redirect dev ${ifbDev}
        tc qdisc replace dev ${ifbDev} root cake \
          bandwidth ${toString cfg.download.base}kbit \
          diffserv4 nat wash docsis ingress split-gso
      '';
      preStop = ''
        tc qdisc del dev ${iface} root 2>/dev/null || true
        tc qdisc del dev ${iface} handle ffff: ingress 2>/dev/null || true
        ip link del ${ifbDev} 2>/dev/null || true
      '';
    };

    systemd.services.cake-autorate = lib.mkIf cfg.autorate.enable {
      description = "CAKE autorate bandwidth adjustment";
      after = ["cake-qos.service"];
      requires = ["cake-qos.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.iproute2 pkgs.fping pkgs.gzip pkgs.coreutils pkgs.gawk];
      environment.CAKE_AUTORATE_SCRIPT_PREFIX = "${cakeAutorate}/lib/cake-autorate";
      serviceConfig = {
        ExecStart = "${cakeAutorate}/lib/cake-autorate/cake-autorate.sh /etc/cake-autorate/config.primary.sh";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    environment.etc."cake-autorate/config.primary.sh" = lib.mkIf cfg.autorate.enable {
      text = lib.concatStringsSep "\n" [
        "dl_if=${ifbDev}"
        "ul_if=${iface}"
        ""
        "adjust_dl_shaper_rate=1"
        "adjust_ul_shaper_rate=1"
        ""
        "min_dl_shaper_rate_kbps=${toString cfg.download.min}"
        "base_dl_shaper_rate_kbps=${toString cfg.download.base}"
        "max_dl_shaper_rate_kbps=${toString cfg.download.max}"
        ""
        "min_ul_shaper_rate_kbps=${toString cfg.upload.min}"
        "base_ul_shaper_rate_kbps=${toString cfg.upload.base}"
        "max_ul_shaper_rate_kbps=${toString cfg.upload.max}"
        ""
        "pinger_binary=fping"
        ""
        "connection_active_thr_kbps=${toString cfg.autorate.connectionActiveThr}"
      ];
    };
  };
}
