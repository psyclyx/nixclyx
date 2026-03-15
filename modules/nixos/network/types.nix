# Shared nftables option types used by both firewall.nix and nftables.nix.
#
# This file doubles as a no-op module spec (so the auto-loader in
# collectSpecs does not crash) and a callable via __functor:
#
#   let nftTypes = import ./types.nix lib; in nftTypes.ruleType
#
let
  mkTypes = lib: let
    ruleValueType = lib.mkOptionType {
      name = "nftables-rule-value";
      description = "string, int, bool, or list of strings/ints";
      check = v:
        builtins.isString v || builtins.isInt v || builtins.isBool v
        || (builtins.isList v
          && (v == [] || builtins.all builtins.isString v || builtins.all builtins.isInt v));
      merge = lib.options.mergeEqualOption;
    };

    ruleType = lib.types.submodule {
      freeformType = lib.types.attrsOf ruleValueType;
      options.verdict = lib.mkOption {
        type = lib.types.str;
        default = "accept";
      };
      options.comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  in {
    inherit ruleValueType ruleType;
  };
in {
  # No-op module spec — the auto-loader imports every .nix file in the
  # modules tree.  Giving this a path + gate keeps it inert.
  path = ["psyclyx" "nixos" "network" "_types"];
  gate = "always";

  # __functor lets callers do `import ./types.nix lib` as if this were a
  # plain function.
  __functor = _: mkTypes;
}
