{
  path = ["psyclyx" "home" "programs" "sshHosts"];
  description = "SSH host entries derived from the egregore fleet";
  options = { lib, ... }: {
    enable = lib.mkEnableOption "SSH host entries generated from egregore";

    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Default IdentityFile applied to `*` (e.g. a sops secret path).";
    };

    forwardAgent = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = ''
        Account used for the generated fleet entries — who *this* client
        logs in as. Session policy, like `identityFile`: egregore holds
        reachability (where a listener is), the client holds the session
        (account, keys), and deployment is dumb ssh against these
        entries.
      '';
    };

    initrdPort = lib.mkOption {
      type = lib.types.port;
      default = 8022;
      description = "SSH port the initrd unlock service listens on, for `<host>-unlock` entries.";
    };
  };
  config = {
    config,
    lib,
    osConfig,
    ...
  }:
    let
      cfg = config.psyclyx.home.programs.sshHosts;
      eg = osConfig.psyclyx.egregore;
      currentHost = osConfig.psyclyx.nixos.host or null;

      siteDomainOf = e: let
        siteName = e.host.site or null;
        site = if siteName != null then eg.entities.${siteName} or null else null;
      in if site != null then site.site.domain or null else null;

      mySite =
        if currentHost != null && eg.entities ? ${currentHost}
        then eg.entities.${currentHost}.host.site or null
        else null;

      # Same-site over the LAN, otherwise over the VPN — every reachable
      # host is named by its site FQDN or its vpn FQDN.
      resolve = e: let
        sameSite = mySite != null && (e.host.site or null) == mySite;
        siteDomain = siteDomainOf e;
        siteFqdn = if siteDomain != null then "${e.attrs.name}.${siteDomain}" else null;
        vpnFqdn = (e.attrs.fqdns or { }).vpn or null;
      in {
        inherit siteFqdn vpnFqdn;
        hostname = if sameSite && siteFqdn != null then siteFqdn else vpnFqdn;
      };

      reachable = lib.filterAttrs (name: e:
        name != currentHost
        && e.type == "host"
        && e.exposures ? ssh
        && (e.wireguard != null || (mySite != null && (e.host.site or null) == mySite))
        && (resolve e).hostname != null
      ) eg.entities;

      mkHost = _name: e: let
        r = resolve e;
        aliases = lib.concatStringsSep " " (lib.unique (
          [ e.attrs.name ]
          ++ lib.optional (r.siteFqdn != null) r.siteFqdn
          ++ lib.optional (r.vpnFqdn != null) r.vpnFqdn
        ));
        keyFqdn = if r.vpnFqdn != null then r.vpnFqdn else r.siteFqdn;
      in lib.nameValuePair aliases {
        HostName = r.hostname;
        Port = e.exposures.ssh.port;
        User = cfg.user;
        ForwardAgent = cfg.forwardAgent;
        HostKeyAlias = keyFqdn;
      };

      # RouterOS switches are reachable over ssh at their management
      # address; SwOS/Sodola are HTTP-only and get no entry.
      switches = lib.filterAttrs (_: e:
        e.type == "routeros"
        && e.exposures ? ssh
        && (e.attrs.address or null) != null
      ) eg.entities;

      mkSwitch = _name: e: lib.nameValuePair e.attrs.name {
        HostName = e.attrs.address;
        User = e.attrs.ssh.user;
      };

      # Initrd unlock: a host whose BMC ref lets it netboot exposes its
      # initrd ssh on a fixed port, reachable at the deploy address.
      unlockHosts = lib.filterAttrs (_: e:
        e.type == "host" && e.refs ? bmc && (e.attrs.deployAddress or null) != null
      ) eg.entities;

      mkUnlock = name: e: lib.nameValuePair "${name}-unlock" {
        HostName = e.attrs.deployAddress;
        Port = cfg.initrdPort;
        User = "root";
        ForwardAgent = false;
        HostKeyAlias = "${name}-initrd";
      };
    in
      lib.mkIf cfg.enable {
        programs.ssh.settings =
          lib.mapAttrs' mkHost reachable
          // lib.mapAttrs' mkSwitch switches
          // lib.mapAttrs' mkUnlock unlockHosts
          // lib.optionalAttrs (cfg.identityFile != null) {
            "*".IdentityFile = cfg.identityFile;
          };
      };
}
