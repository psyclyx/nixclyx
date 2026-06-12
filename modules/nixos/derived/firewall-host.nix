# Egregore host.firewall → NixOS firewall configuration.
#
# Per-host firewall declarations (zone overrides for non-network-entity
# interfaces, input policies, masquerade rules) live in the host's
# egregore entity. This projection materializes them into
# psyclyx.nixos.network.firewall.*.
#
# Zone interface derivation (network.zone + host.interfaces) and
# forward-rule emission (globals.policy) live in firewall-policy.nix;
# this projection adds the per-host slice.
{ config, lib, ... }:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host or null;
  me = lib.attrByPath ["entities" hostname "host"] null eg;
  fw = if me == null then {} else (me.firewall or {});

  zonesExtra = fw.zones or {};
  inputDecls = fw.input or {};
  masqDecls = fw.masquerade or [];

  # Normalize input declaration: bare "accept"/"drop"/"reject" is
  # shorthand for `{ policy = ...; }`. Submodule form passes through.
  normalizeInput = decl:
    if builtins.isString decl
    then { policy = decl; }
    else decl;

  normalizedInput = lib.mapAttrs (_: normalizeInput) inputDecls;

  hasContent =
    zonesExtra != {} || inputDecls != {} || masqDecls != [];
in {
  config = lib.mkIf hasContent {
    psyclyx.nixos.network.firewall = {
      zones = lib.mapAttrs
        (_: z: { interfaces = z.extraInterfaces; })
        zonesExtra;
      input = normalizedInput;
      masquerade = masqDecls;
    };
  };
}
