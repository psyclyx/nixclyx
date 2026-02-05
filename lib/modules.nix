rec {
  last = l: builtins.elemAt l (builtins.length l - 1);

  mkModule = spec:
    moduleArgs @ {config, lib, pkgs, nixclyx ? null, ...}: let
      cfg = lib.attrByPath spec.path {} config;
      args = moduleArgs // {inherit cfg;};
      eval = x:
        if builtins.isFunction x
        then x args
        else x;

      hasVariant = spec ? variant;
      variantName = if hasVariant then last spec.path else null;

      hasEnable = !hasVariant && spec.description or null != null;
      gate =
        if hasVariant
        then (a: lib.getAttrFromPath spec.variant a.config == variantName)
        else spec.gate or true;

      pathOptions = eval (spec.options or {});
    in {
      imports = spec.imports or [];

      options = lib.recursiveUpdate
        (if pathOptions == {} && !hasEnable
         then {}
         else lib.setAttrByPath spec.path (
          (lib.optionalAttrs hasEnable {
            enable = lib.mkEnableOption spec.description;
          })
          // pathOptions
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
