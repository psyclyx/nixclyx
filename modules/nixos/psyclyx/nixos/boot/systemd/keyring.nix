{
  config,
  lib,
  pkgs,
  ...
}:
let
  unlockServices = lib.filter (lib.hasPrefix "unlock-bcachefs-") (
    lib.attrNames config.boot.initrd.systemd.services
  );

  cfg = config.psyclyx.nixos.boot.systemd.keyring;
in
{
  options = {
    psyclyx.nixos.boot.systemd.keyring = {
      enable = lib.mkEnableOption "link session keyring in init, share with relevant services";
    };

    boot.initrd.systemd.services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            config = lib.mkIf (lib.hasPrefix "unlock-bcachefs-" name) {
              serviceConfig.KeyringMode = "shared";
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
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
