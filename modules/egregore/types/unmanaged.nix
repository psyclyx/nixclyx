# Entity type: unmanaged device (documentation only).
{ lib, egregorLib, config, ... }:
egregorLib.mkType {
  name = "unmanaged";
  topConfig = config;
  description = "Unmanaged device — documentation only.";

  options = {
    model = lib.mkOption { type = lib.types.str; default = ""; };
    description = lib.mkOption { type = lib.types.str; default = ""; };
  };

  attrs = _name: entity: _top: {
    label = entity.unmanaged.model;
    model = entity.unmanaged.model;
  };
}
