# Entity type: site (a physical location in the fleet).
#
# Sites are where infrastructure lives. They have a location label,
# an optional DNS domain for host naming, and optional network
# connectivity details. Sites know nothing about how they're connected
# to each other — that's the VPN/overlay layer's concern.
{ lib, egregorLib, config, ... }:
egregorLib.mkType {
  name = "site";
  topConfig = config;
  description = "A physical location in the fleet.";

  options = {
    location = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Human-readable location description.";
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "DNS zone for hosts at this site (e.g. apt.psyclyx.net).";
    };
  };

  attrs = name: entity: _top: let
    s = entity.site;
  in {
    domain = s.domain;
    label = if s.location != "" then s.location else name;
  };
}
