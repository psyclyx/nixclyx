# Colmena deployment metadata per host: *where and how* each node is shipped
# (targets + tags). Consumed only by `hive.nix`; `configurations` in
# default.nix never see this. Targets are derived from each host's egregore
# entity (its computed deployAddress, plus the `ssh` exposure's port)
# present; tags and the
# handful of hosts not yet in egregore stay declared here.
{
  nixclyx,
  lib,
}:
let
  spec = import ./egregore.nix;
  egregorePkg = import spec.lib {inherit lib;};
  eg = egregorePkg.eval {modules = [spec.root];};

  # Derive deployment target from a host's egregore entity (its computed
  # deployAddress), if it has one. Reachability only — no accounts.
  # Deployment is dumb ssh against the client's ssh config entries
  # (which carry the user and keys); the graph only says where the
  # listener is.
  fromEgregore = name: let
    e = eg.entities.${name} or { host = {}; attrs = {}; };
    target = e.attrs.deployAddress or null;
    sshPort = e.exposures.ssh.port or 22;
  in
    lib.optionalAttrs (target != null) {
      targetHost = target;
    }
    // lib.optionalAttrs (sshPort != 22) {
      targetPort = sshPort;
    };
in {
  sigil =
    fromEgregore "sigil"
    // {
      tags = ["apartment" "workstation" "desktop" "fixed"];
      allowLocalDeployment = true;
    };

  omen =
    fromEgregore "omen"
    // {
      tags = ["workstation" "laptop"];
      allowLocalDeployment = true;
    };

  glyph =
    fromEgregore "glyph"
    // {
      tags = ["workstation" "laptop"];
      allowLocalDeployment = true;
    };

  iyr =
    fromEgregore "iyr"
    // {
      tags = ["apartment" "router" "minipc" "fixed"];
    };

  tleilax =
    fromEgregore "tleilax"
    // {
      tags = ["server" "colo" "fixed"];
    };

  semuta =
    fromEgregore "semuta"
    // {
      tags = ["server" "vps" "fixed"];
    };

  lab-1 =
    fromEgregore "lab-1"
    // {
      tags = ["server" "apartment" "lab" "fixed"];
    };

  lab-2 =
    fromEgregore "lab-2"
    // {
      tags = ["server" "apartment" "lab" "fixed"];
    };

  lab-3 =
    fromEgregore "lab-3"
    // {
      tags = ["server" "apartment" "lab" "fixed"];
    };

  lab-4 =
    fromEgregore "lab-4"
    // {
      tags = ["server" "apartment" "lab" "fixed"];
    };
}
