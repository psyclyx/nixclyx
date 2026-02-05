rec {
  mkModule = spec:
    moduleArgs @ {config, lib, ...}: let
      cfg = lib.attrByPath spec.path {} config;
      args = moduleArgs // {inherit cfg;};
      eval = x:
        if builtins.isFunction x
        then x args
        else x;

      hasEnable = spec.description or null != null;
      gate = spec.gate or true;
    in {
      imports = spec.imports or [];

      options = lib.recursiveUpdate
        (lib.setAttrByPath spec.path (
          (lib.optionalAttrs hasEnable {
            enable = lib.mkEnableOption spec.description;
          })
          // eval (spec.options or {})
        ))
        (eval (spec.extraOptions or {}));

      config = let
        body = eval (spec.config or null);
      in
        if body == null
        then {}
        else if gate == false
        then body
        else if gate == true
        then lib.mkIf cfg.enable body
        else lib.mkIf (gate args) body;
    };

  withConfig = fn: spec:
    spec
    // {
      config = configArgs: let
        base = let
          c = spec.config or null;
        in
          if c == null
          then {}
          else if builtins.isFunction c
          then c configArgs
          else c;
        extra =
          if builtins.isFunction fn
          then fn configArgs
          else fn;
      in
        configArgs.lib.mkMerge [base extra];
    };

  withImports = newImports: spec:
    spec // {imports = (spec.imports or []) ++ newImports;};
}
