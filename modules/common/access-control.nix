{ lib, config, ... }:
let
  inherit (lib)
    attrNames
    mkOption
    mkDefault
    mkIf
    removeAttrs
    types
    ;

  principalOptions = {
    _grant = mkOption {
      type = types.bool;
    };

    # Read-only computed indices
    _flatScopes = mkOption {
      type = types.listOf (types.listOf types.str);
      readOnly = true;
      internal = true;
    };

    _hasScope = mkOption {
      type = types.functionTo types.bool;
      readOnly = true;
      internal = true;
    };
  };

  principalModule =
    {
      parentGrant ? false,
      config,
      ...
    }:
    {
      options = principalOptions;
      freeformType = types.attrsOf (
        types.submoduleWith {
          specialArgs = {
            parentGrant = config._grant;
          };
          modules = [
            (
              { parentGrant, ... }:
              {
                config._grant = mkDefault parentGrant;
              }
            )
          ];
        }
      );
    };

  scopeOptionAttrs = attrNames principalOptions;

  subscopeAttrs = scopeCfg: removeAttrs scopeCfg scopeOptionAttrs;

  collectFlatScopes =
    path: principalScopeCfg:
    let
      currentGrant = principalScopeCfg._grant or false;
      principalSubscopeCfg = subscopeAttrs principalScopeCfg;
    in
    (lib.optional currentGrant path)
    ++ (lib.concatLists (
      lib.mapAttrsToList (name: value: collectFlatScopes (path ++ [ name ]) value) principalSubscopeCfg
    ));

  mkHasScope = flatScopes: (flatScope: builtins.elem flatScope flatScopes);

in
{
  options = {
    principals = mkOption {
      type = types.attrsOf (
        types.submoduleWith {
          modules = [ (principalModule { parentGrant = false; }) ];
        }
      );
      default = { };
    };

    scopes = mkOption {
      type = types.submoduleWith {
        options = {
          _description = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          _principals = mkOption {
            type = types.listOf types.str;
            readOnly = true;
            internal = true;
          };
        };
        freeformType = types.attrs;
      };
      default = { };
    };
  };

  config = {
    principals = lib.mapAttrs (
      principalName: principalConfig:
      let
        _scopes = collectFlatScopes [ ] principalConfig;
        _hasScope = scope: builtins.elem scope _scopes;
      in
      {
        inherit _scopes _hasScope;
      }
    ) config.principals;

    assertions = [
      {
        assertion = true; # Add your scope validation logic here
        message = "Scope validation placeholder";
      }
    ];
  };
}
