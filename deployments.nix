# Colmena deployment metadata per host: *where and how* each node is shipped
# (targets + tags). Consumed only by `hive.nix`; `configurations` in
# default.nix never see this. Targets are derived from each host's egregore
# entity (deployAddress / deployUser / sshPort) where present; tags and the
# handful of hosts not yet in egregore stay declared here.
{
  nixclyx,
  lib,
}:
let
  spec = import ./egregore.nix;
  egregorePkg = import spec.lib {inherit lib;};
  eg = egregorePkg.eval {modules = [spec.root];};

  # Derive deployment target from a host's egregore entity, if it declares one.
  fromEgregore = name: let
    h = (eg.entities.${name} or {host = {};}).host or {};
    target = h.deployAddress or null;
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

  # Not in egregore yet — fromEgregore returns {}, target stays implicit.
  omen =
    fromEgregore "omen"
    // {
      tags = ["workstation" "laptop"];
      allowLocalDeployment = true;
    };

  # Not in egregore yet — manual target.
  glyph = {
    tags = ["workstation" "laptop"];
    allowLocalDeployment = true;
    targetHost = "10.1.0.240";
    targetUser = "root";
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
