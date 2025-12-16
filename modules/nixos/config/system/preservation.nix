{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkAfter
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.psyclyx.system.preservation;
in
{
  options = {
    psyclyx.system.preservation = {
      enable = mkEnableOption "preservation (impermanence)";

      preserveAt = mkOption {
        default = "/persist";
        type = types.str;
      };

      preserve = mkOption {
        type = types.attrs;
        default = { };
      };

      restore.bcachefs = {
        enable = mkEnableOption "restore to blank root on boot";

        device = mkOption { type = types.nullOr types.str; };

        rootSubvolume = mkOption {
          type = types.str;
          default = "live/root";
        };

        blankRootName = mkOption {
          type = types.str;
          default = "blank";
        };

        rootSnapshots = mkOption {
          type = types.str;
          default = "snapshots/root";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      preservation = {
        enable = true;

        preserveAt."${cfg.preserveAt}" = {
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd"
          ];
          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
          ]
          ++ (map (x: x.path) (config.services.openssh.hostKeys or [ ]))
          ++ (map (x: {
            file = x;
            inInitrd = true;
          }) (config.boot.initrd.network.ssh.hostKeys or [ ]));
        };
      };
    }

    { preservation.preserveAt."${cfg.preserveAt}" = cfg.preserve; }

    (
      let
        inherit (cfg.restore.bcachefs)
          enable
          device
          rootSubvolume
          blankRootName
          rootSnapshots
          ;
      in
      (mkIf enable {
        boot.initrd.systemd.services.bcachefs-rollback = {
          description = "Rollback bcachefs root subvolume to blank snapshot";
          wantedBy = [ "initrd.target" ];
          after = [ ];
          before = [ "sysroot.mount" ];
          path = [ pkgs.bcachefs-tools ];
          serviceConfig.Type = "oneshot";
          script = ''
            mkdir /bcachefs_tmp

            mount "${device}" /bcachefs_tmp && {
              if [[ -e "/bcachefs_tmp/${rootSubvolume}" ]]; then
                mkdir -p "/bcachefs_tmp/${rootSnapshots}"
                timestamp=$(date --date="@$(stat -c %Y \"/bcachefs_tmp/${rootSubvolume}\")" "+%Y-%m-%-d_%H:%M:%S")
                mv "/bcachefs_tmp/${rootSubvolume}" "/bcachefs_tmp/${rootSnapshots}/''${timestamp}"
              fi

              for snapshot in $(find "/bcachefs_tmp/${rootSnapshots}" \
                -maxdepth 1 \
                -type d \
                -name '@*' \
                -not -name "${blankRootName}" \
                -mtime +30 \
              ); do
                chattr -i "''${snapshot}/var/empty"
                bcachefs subvolume delete "''${snapshot}"
              done

              bcachefs subvolume snapshot "/bcachefs_tmp/${rootSnapshots}/${blankRootName}" "/bcachefs_tmp/${rootSubvolume}"
              umount /bcachefs_tmp
            }
          '';
        };
      })
    )
  ]);
}
