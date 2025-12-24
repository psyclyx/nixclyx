{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrNames
    filter
    hasPrefix
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  unlockServices = filter (hasPrefix "unlock-bcachefs-") (
    attrNames config.boot.initrd.systemd.services
  );

  cfg = config.psyclyx.nixos.boot.systemd.keyring;
in
{
  options = {
    psyclyx.nixos.boot.systemd.keyring = {
      enable = mkEnableOption "link session keyring in init, share with relevant services";
    };

    boot.initrd.systemd.services = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            config = mkIf (hasPrefix "unlock-bcachefs-" name) {
              serviceConfig.KeyringMode = "shared";
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.systemd = {
      initrdBin = [ pkgs.keyutils ];
      services = {
        link-user-keyring = {
          description = "Link user keyring to session keyring";
          wantedBy = [ "initrd.target" ];
          before = map (s: "${s}.service") unlockServices ++ [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            KeyringMode = "shared";
            ExecStart = "${pkgs.keyutils}/bin/keyctl link @u @s";
          };
        };
      };
    };
  };
}
