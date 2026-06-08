# Entity type: unmanaged device (documentation only).
{
  egregoreType = { lib, ... }: {
    name = "unmanaged";
    description = "Unmanaged device — documentation only.";

    options = {
      model = lib.mkOption { type = lib.types.str; default = ""; };
      description = lib.mkOption { type = lib.types.str; default = ""; };
    };

    attrs = _name: entity: _top: {
      label = entity.unmanaged.model;
      model = entity.unmanaged.model;
    };
  };
}
