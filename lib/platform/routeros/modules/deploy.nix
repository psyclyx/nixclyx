# RouterOS platform — the deploy action.
#
# Build ≠ place: the `.rsc` is the build; this places it. The host is the
# last argument and everything before it is handed to ssh/scp, so
# connection knobs go where ssh expects them. The account, port, and jump
# defaults come from your ssh config, as with ssh itself.
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
      usage() {
        cat >&2 <<'USAGE'
      usage: routeros-deploy [ssh/scp options] <host>

        The host is the last argument; everything before it is passed to
        ssh and scp, so options go where ssh expects them:

          routeros-deploy -J bastion -p 2222 mdf-agg01

        Account, port, and jump defaults come from your ssh config. The
        switch must accept your key.
      USAGE
      }

      [ $# -ge 1 ] || { usage; exit 2; }
      host="''${!#}"
      opts=("''${@:1:$#-1}")

      stamp=$(date +%Y%m%d-%H%M%S)
      backup="preflight-${identity}-$stamp"
      local_backup="''${TMPDIR:-/tmp}/$backup.backup"

      echo "Backing up $host to $local_backup ..." >&2
      # $backup is meant to expand here, not on the switch.
      # shellcheck disable=SC2029
      ssh "''${opts[@]}" "$host" "/system backup save name=$backup"
      scp "''${opts[@]}" "$host:/$backup.backup" "$local_backup"

      echo "Uploading $host:/${rscName} ..." >&2
      scp "''${opts[@]}" "${rsc}" "$host:/${rscName}"

      echo "Resetting $host (it will reboot) ..." >&2
      ssh "''${opts[@]}" "$host" \
        "/system reset-configuration keep-users=yes no-defaults=yes run-after-reset=${rscName}"

      cat >&2 <<EOF

      $host reboots and applies ${rscName}.
      If it comes back wrong:
        scp "''${opts[*]}" "$local_backup" "$host:/"
        ssh "''${opts[*]}" "$host" '/system backup load name=$backup'
      EOF
    '';
  };
}
