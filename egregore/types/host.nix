# Entity type: host (a machine with network addresses).
{ lib, egregorLib, config, ... }:
egregorLib.mkType {
  name = "host";
  topConfig = config;
  description = "A machine with network addresses and hardware facts.";

  options = {
    addresses = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          ipv4 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          ipv6 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      });
      default = {};
    };
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.device = lib.mkOption { type = lib.types.str; };
      });
      default = {};
    };
    mac = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };
    wireguard = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          publicKey = lib.mkOption { type = lib.types.str; };
          endpoint = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          exportedRoutes = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
          allowedNetworks = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        };
      });
      default = null;
    };
    roles = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
    sshPort = lib.mkOption { type = lib.types.int; default = 22; };
    deployAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH target for deployment. Null = not remotely deployable (e.g. laptops).";
    };
    publicIPv4 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    publicIPv6 = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    hardware = lib.mkOption {
      type = lib.types.submodule {
        options.tpm = lib.mkOption { type = lib.types.bool; default = false; };
      };
      default = {};
    };
    exporters = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          port = lib.mkOption { type = lib.types.int; };
          networks = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        };
      });
      default = {};
    };
  };

  attrs = name: entity: _top: let
    h = entity.host;
    vpn = h.addresses.vpn or null;
  in {
    address = if vpn != null then vpn.ipv4 else null;
    roles = h.roles;
    sshPort = h.sshPort;
    deployAddress = h.deployAddress;
    hasTpm = h.hardware.tpm;
    label = builtins.concatStringsSep ", " h.roles;
  };

  verbs = name: entity: _top: let
    h = entity.host;
    target = h.deployAddress;
    portArg = lib.optionalString (h.sshPort != 22) "-p ${toString h.sshPort}";
    sshTarget = "root@${target}";
  in lib.optionalAttrs (target != null) {
    deploy = {
      description = "Build and deploy NixOS configuration.";
      impl = ''
        DEPLOY_DIR="''${EGREGORE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
        echo "Building ${name}..."
        result=$(nix-build "$DEPLOY_DIR/hive-build.nix" --argstr hostname "${name}" --no-out-link 2>&1 | tail -1)
        echo "Copying closure to ${target}..."
        NIX_SSHOPTS="${portArg}" nix-copy-closure --to ${sshTarget} "$result"
        echo "Switching..."
        ssh ${portArg} ${sshTarget} "$result/bin/switch-to-configuration switch"
        echo "Deployed ${name}."
      '';
    };
    deploy-dry = {
      description = "Build NixOS configuration without deploying.";
      pure = true;
      impl = let
        result = "$(nix-build \"$DEPLOY_DIR/hive-build.nix\" --argstr hostname \"${name}\" --no-out-link 2>&1 | tail -1)";
      in ''
        DEPLOY_DIR="''${EGREGORE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
        echo "Building ${name}..."
        ${result}
      '';
    };
  };
}
