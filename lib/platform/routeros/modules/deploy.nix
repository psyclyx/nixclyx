# RouterOS platform — the deploy action.
#
# Target-agnostic: the device is an argument, not baked into the artifact,
# so a config that changes the management address still deploys to the
# address you know. The `.rsc` is the build; this is the placement.
{ config, lib, pkgs, ... }:
let
  identity = config.routeros.identity;
  rscName = "${identity}.rsc";
  rsc = config.system.build.script;
in {
  system.build.deploy = pkgs.writeShellApplication {
    name = "routeros-deploy";
    runtimeInputs = [ pkgs.openssh pkgs.coreutils ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "usage: routeros-deploy <host> [ssh/scp args...]" >&2
        exit 1
      fi
      target="$1"; shift || true

      stamp=$(date +%Y%m%d-%H%M%S)
      backup="preflight-${identity}-$stamp"

      # Back up first, and pull it off the switch: a copy that only lives
      # on the device it protects isn't a backup.
      echo "Backing up to /tmp/$backup.backup..." >&2
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$@" "admin@$target" "/system backup save name=$backup"
      scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$@" "admin@$target:/$backup.backup" "/tmp/$backup.backup"

      echo "Uploading ${rscName}..." >&2
      scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$@" "${rsc}" "admin@$target:/${rscName}"

      echo "Resetting configuration (switch will reboot)..." >&2
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$@" "admin@$target" \
        "/system/reset-configuration keep-users=yes no-defaults=yes run-after-reset=${rscName}"

      echo "" >&2
      echo "Deploy complete. ${identity} reboots and applies ${rscName}." >&2
      echo "If it comes back wrong, restore with:" >&2
      echo "  scp /tmp/$backup.backup admin@$target:/" >&2
      echo "  ssh admin@$target '/system backup load name=$backup'" >&2
    '';
  };
}
