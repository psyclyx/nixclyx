{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.boot.loader.zfsbootmenu;
  zfs = config.boot.zfs.package;
in
{
  options.boot.loader.zfsbootmenu = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    datasetPrefix = mkOption {
      type = types.str;
      default = "rpool/root";
    };

    keepGenerations = mkOption {
      type = types.int;
      default = 10;
    };
  };

  config = mkIf cfg.enable {
    boot.loader.external = {
      enable = true;
      installHook = pkgs.writeShellScript "install" ''
        set -e

        profile="$1"
        # Extract generation number from either a -link symlink or the actual profile
        if [[ "$profile" =~ -([0-9]+)-link$ ]]; then
          gen="''${BASH_REMATCH[1]}"
        else
          # Fallback: try to get generation from the calling context or use timestamp
          gen=$(${pkgs.coreutils}/bin/date +%s)
        fi
        dataset="${cfg.datasetPrefix}-''${gen}"

        # Find previous dataset (highest numbered that exists)
        prev=""
        for ((i = gen - 1; i > 0; i--)); do
          if ${zfs}/bin/zfs list -H "${cfg.datasetPrefix}-''${i}" &>/dev/null; then
            prev="${cfg.datasetPrefix}-''${i}"
            break
          fi
        done

        # Create dataset if it doesn't exist
        if ! ${zfs}/bin/zfs list -H "''${dataset}" &>/dev/null; then
          if [ -n "''${prev}" ]; then
            # Clone from previous
            ${zfs}/bin/zfs snapshot "''${prev}@pre-''${gen}"
            ${zfs}/bin/zfs clone "''${prev}@pre-''${gen}" "''${dataset}"
          else
            # Clone from base
            ${zfs}/bin/zfs snapshot "${cfg.datasetPrefix}@pre-''${gen}"
            ${zfs}/bin/zfs clone "${cfg.datasetPrefix}@pre-''${gen}" "''${dataset}"
          fi

          ${zfs}/bin/zfs set canmount=noauto "''${dataset}"
          ${zfs}/bin/zfs set mountpoint=/ "''${dataset}"
        fi

        # Copy kernel/initrd to dataset
        tmp="/tmp/zbm-$$"
        trap 'umount "''${tmp}" 2>/dev/null || true; rmdir "''${tmp}" 2>/dev/null || true' EXIT

        mkdir -p "''${tmp}"
        mount -t zfs "''${dataset}" "''${tmp}"
        mkdir -p "''${tmp}/boot"

        kernel=$(readlink -f "''${profile}/kernel")
        initrd=$(readlink -f "''${profile}/initrd")
        kver=$(echo "''${kernel}" | ${pkgs.gnused}/bin/sed -E 's|.*linux-([0-9]+\.[0-9]+\.[0-9]+).*|\1|')

        cp "''${kernel}" "''${tmp}/boot/vmlinuz-''${kver}"
        cp "''${initrd}" "''${tmp}/boot/initramfs-''${kver}"

        umount "''${tmp}"
        rmdir "''${tmp}"

        # Set ZFS properties for ZFSBootMenu
        ${zfs}/bin/zfs set org.zfsbootmenu:kernel="/boot/vmlinuz-''${kver}" "''${dataset}"
        ${zfs}/bin/zfs set org.zfsbootmenu:initrd="/boot/initramfs-''${kver}" "''${dataset}"
        ${zfs}/bin/zfs set org.zfsbootmenu:commandline="init=$(readlink -f ''${profile}/init) ${toString config.boot.kernelParams}" "''${dataset}"

        # Clean old generations
        if [ ${toString cfg.keepGenerations} -gt 0 ]; then
          ${zfs}/bin/zfs list -H -o name | grep "^${cfg.datasetPrefix}-[0-9]\+$" | \
            sort -t- -k3 -n -r | tail -n +$((${toString cfg.keepGenerations} + 1)) | \
            while read ds; do
              # Destroy snapshots first, then dataset
              ${zfs}/bin/zfs list -H -t snapshot -o name -r "''${ds}" | \
                xargs -r -n1 ${zfs}/bin/zfs destroy
              ${zfs}/bin/zfs destroy "''${ds}"
            done
        fi

        # Set as bootfs
        pool=$(echo "''${dataset}" | cut -d/ -f1)
        ${zfs}/bin/zpool set bootfs="''${dataset}" "''${pool}"
      '';
    };
  };
}
