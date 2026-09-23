# Colmena deployment metadata per host: *where and how* each node is shipped
# (targets + tags). Consumed only by `hive.nix`; `configurations` in
# default.nix never see this. Targets are derived from each host's egregore
# entity (its computed deployAddress, plus deployUser / sshPort) where
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
  # deployAddress), if it has one.
  fromEgregore = name: let
    e = eg.entities.${name} or { host = {}; attrs = {}; };
    h = e.host or {};
    target = e.attrs.deployAddress or null;
  in
    lib.optionalAttrs (target != null) {
      targetHost = target;
      targetUser = h.deployUser or "root";
    }
    // lib.optionalAttrs ((h.sshPort or 22) != 22) {
      targetPort = h.sshPort;
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
