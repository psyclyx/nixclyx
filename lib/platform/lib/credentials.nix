# Shared connection helper for the HTTP/Redfish platform tools.
#
# Credentials for a named target are resolved in a standard order:
#
#   1. an explicit override: <PREFIX>_USER / <PREFIX>_PASSWORD
#   2. ~/.netrc (or $NETRC), by `machine <host>`
#
# ~/.netrc is the established place for per-host HTTP credentials; a
# home-manager activation can write it from sops, and every curl-based
# tool reads it. Home-manager likewise supplies ssh keys via ~/.ssh/config
# for the RouterOS tool. Nothing here knows sops or the fleet — the tools
# just take a host and find its credentials the standard way.
{ lib }:
rec {
  # Shell prologue defining `resolve_creds <host>`: sets `user` and
  # `password`, or fails with a message naming both ways to provide them.
  resolve = prefix: ''
    resolve_creds() {
      local host="$1"
      local netrc="''${NETRC:-$HOME/.netrc}"
      user="''${${prefix}_USER:-}"
      password="''${${prefix}_PASSWORD:-}"
      if { [ -z "$user" ] || [ -z "$password" ]; } && [ -f "$netrc" ]; then
        user="''${user:-$(awk -v h="$host" '$1 == "machine" && $2 == h { print $4 }' "$netrc")}"
        password="''${password:-$(awk -v h="$host" '$1 == "machine" && $2 == h { print $6 }' "$netrc")}"
      fi
      if [ -z "$user" ] || [ -z "$password" ]; then
        echo "no credentials for $host" >&2
        echo "  set ${prefix}_USER and ${prefix}_PASSWORD, or add:" >&2
        echo "  machine $host login <user> password <pass>" >&2
        echo "to $netrc" >&2
        return 1
      fi
    }
  '';
}
