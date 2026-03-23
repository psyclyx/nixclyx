{
  path = ["psyclyx" "nixos" "services" "home-assistant"];
  description = "Enables Home Assistant, with @psyclyx's config";
  options = {lib, ...}: {
    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["/dev/ttyACM0"];
      description = "Device paths to pass through to the container.";
    };
    trustedProxies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["10.157.0.1"];
      description = "IP addresses trusted as reverse proxies (enables use_x_forwarded_for).";
    };
    discovery = {
      interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "enp1s0.110";
        description = ''
          Parent interface for a macvlan network enabling mDNS/SSDP device
          discovery.  When null, the container uses bridge networking with
          port mapping instead (no L2 discovery).

          A host-side macvlan shim is created via systemd-networkd so the
          container can route through the host (works around the kernel
          macvlan parent-isolation limitation).
        '';
      };
      parentNetworkUnit = lib.mkOption {
        type = lib.types.str;
        example = "31-enp1s0.110";
        description = "systemd-networkd unit name of the parent interface's .network file.";
      };
      subnet = lib.mkOption {
        type = lib.types.str;
        example = "10.0.110.0/24";
        description = "Subnet CIDR for the macvlan network.";
      };
      address = lib.mkOption {
        type = lib.types.str;
        example = "10.0.110.100";
        description = "Static IPv4 address for the Home Assistant container.";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        example = "10.0.110.2";
        description = ''
          IP assigned to the host-side macvlan shim.  The container uses this
          as its default gateway and DNS server.  Must be a free address on
          the same subnet — NOT the regular gateway address (macvlan
          isolation prevents the container from reaching it).
        '';
      };
      firewallZone = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "lan";
        description = "Firewall zone to add the macvlan shim interface to.";
      };
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    ports = config.psyclyx.nixos.network.ports.home-assistant.tcp;
    port = builtins.head ports;
    hasDiscovery = cfg.discovery.interface != null;
    hasTrustedProxies = cfg.trustedProxies != [];
    shimIface = "hass-shim";
    networkName = "hass-discovery";

    # Minimal configuration.yaml with proxy trust + default integrations.
    # Bind-mounted into the container; HA stores UI-managed config in
    # .storage/ so this file only needs the YAML-only settings.
    configYaml = pkgs.writeText "ha-configuration.yaml" (lib.concatStringsSep "\n" (
      ["default_config:"]
      ++ lib.optionals hasTrustedProxies [
        ""
        "http:"
        "  use_x_forwarded_for: true"
        "  trusted_proxies:"
      ]
      ++ map (p: "    - ${p}") cfg.trustedProxies
    ));
  in {
    psyclyx.nixos = {
      network.ports.home-assistant = lib.mkDefault 8123;
      system.containers.enable = lib.mkDefault true;

      # Add the shim interface to the specified firewall zone
      network.firewall.zones.${cfg.discovery.firewallZone}.interfaces =
        lib.mkIf (hasDiscovery && cfg.discovery.firewallZone != null) [shimIface];
    };

    # networkd: macvlan shim netdev
    systemd.network.netdevs."40-${shimIface}" = lib.mkIf hasDiscovery {
      netdevConfig = {
        Name = shimIface;
        Kind = "macvlan";
      };
      macvlanConfig.Mode = "bridge";
    };

    # networkd: shim network — /32 address to avoid conflicting with the
    # parent's subnet route; host route sends container traffic via the shim.
    systemd.network.networks."40-${shimIface}" = lib.mkIf hasDiscovery {
      matchConfig.Name = shimIface;
      address = ["${cfg.discovery.gateway}/32"];
      routes = [
        {
          Destination = "${cfg.discovery.address}/32";
          Scope = "link";
        }
      ];
      linkConfig.RequiredForOnline = "no";
    };

    # Attach the macvlan to the parent interface's network unit
    systemd.network.networks.${cfg.discovery.parentNetworkUnit}.macvlan =
      lib.mkIf hasDiscovery [shimIface];

    # Podman macvlan network for L2 device discovery
    systemd.services."podman-network-${networkName}" = lib.mkIf hasDiscovery {
      description = "Create podman macvlan network for Home Assistant";
      after = ["podman.service"];
      requires = ["podman.service"];
      before = ["podman-homeassistant.service"];
      requiredBy = ["podman-homeassistant.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [config.virtualisation.podman.package];
      script = ''
        if ! podman network exists ${networkName}; then
          podman network create -d macvlan \
            --subnet=${cfg.discovery.subnet} \
            --gateway=${cfg.discovery.gateway} \
            -o parent=${cfg.discovery.interface} \
            ${networkName}
        fi
      '';
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.homeassistant = {
        volumes =
          ["home-assistant:/config"]
          ++ lib.optional hasTrustedProxies
            "${configYaml}:/config/configuration.yaml:ro";
        environment.TZ = "America/Los_Angeles";
        image = "ghcr.io/home-assistant/home-assistant:stable";
        ports = lib.optionals (!hasDiscovery) [
          "${toString port}:8123"
        ];
        extraOptions =
          (
            if hasDiscovery
            then [
              "--network=${networkName}:ip=${cfg.discovery.address}"
              "--dns=${cfg.discovery.gateway}"
            ]
            else []
          )
          ++ map (d: "--device=${d}") cfg.devices;
      };
    };
  };
}
