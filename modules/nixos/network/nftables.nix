{
  path = ["psyclyx" "nixos" "network" "nftables"];
  gate = "always";
  options = {lib, ...}: let
    nftTypes = import ./types.nix lib;
    inherit (nftTypes) ruleValueType ruleType;

    chainType = lib.types.submodule {
      options = {
        type = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["filter" "nat" "route"]);
          default = null;
        };
        hook = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        priority = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.int lib.types.str);
          default = null;
        };
        policy = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["accept" "drop"]);
          default = null;
        };
        device = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        rules = lib.mkOption {
          type = lib.types.listOf ruleType;
          default = [];
        };
        content = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
    };

    tableType = lib.types.submodule {
      options = {
        family = lib.mkOption {
          type = lib.types.enum ["ip" "ip6" "inet" "arp" "bridge" "netdev"];
        };
        chains = lib.mkOption {
          type = lib.types.attrsOf chainType;
          default = {};
        };
        content = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
    };
  in {
    tables = lib.mkOption {
      type = lib.types.attrsOf tableType;
      default = {};
    };
  };
  config = {
    cfg,
    config,
    lib,
    ...
  }: let
    compileEntry = key: value:
      if builtins.isBool value then
        (if value then key else null)
      else if builtins.isInt value then
        "${key} ${toString value}"
      else if builtins.isString value then
        "${key} ${value}"
      else if builtins.isList value then
        if value == [] then null
        else let
          inner =
            if builtins.isInt (builtins.head value)
            then lib.concatMapStringsSep ", " toString value
            else lib.concatMapStringsSep ", " (s: ''"${s}"'') value;
        in "${key} { ${inner} }"
      else null;

    compileRule = rule: let
      reserved = ["verdict" "comment"];
      entries = lib.filterAttrs (k: v:
        !(builtins.elem k reserved) && !(builtins.isBool v && !v)
      ) rule;
      compiled = lib.filter (x: x != null)
        (lib.mapAttrsToList compileEntry entries);
      commentSuffix = lib.optionalString (rule.comment != null)
        " comment ${builtins.toJSON rule.comment}";
    in
      lib.concatStringsSep " " (compiled ++ [rule.verdict]) + commentSuffix;

    compileChain = name: chain: let
      preamble = lib.optional (chain.type != null) (
        "type ${chain.type} hook ${chain.hook} priority ${toString chain.priority};"
        + lib.optionalString (chain.device != null) " device ${chain.device};"
        + lib.optionalString (chain.policy != null) " policy ${chain.policy};"
      );
      ruleLines = map compileRule chain.rules;
      contentLines = lib.filter (l: l != "") (lib.splitString "\n" chain.content);
      body = preamble ++ ruleLines ++ contentLines;
      indented = lib.concatMapStringsSep "\n" (l: "    ${l}") body;
    in "  chain ${name} {\n${indented}\n  }";

    compileTable = name: table: let
      contentLines = lib.filter (l: l != "") (lib.splitString "\n" table.content);
      contentBlock = lib.concatMapStringsSep "\n" (l: "  ${l}") contentLines;
      chainBlock = lib.concatStringsSep "\n" (lib.mapAttrsToList compileChain table.chains);
      inner = lib.concatStringsSep "\n" (lib.filter (s: s != "") [contentBlock chainBlock]);
    in "table ${table.family} ${name} {\n${inner}\n}";

    ruleset = lib.concatStringsSep "\n" (lib.mapAttrsToList compileTable cfg.tables);

    baseChainAssertions = lib.concatLists (lib.mapAttrsToList (tname: table:
      lib.mapAttrsToList (cname: chain: {
        assertion = let
          anySet = chain.type != null || chain.hook != null || chain.priority != null;
          allSet = chain.type != null && chain.hook != null && chain.priority != null;
        in !anySet || allSet;
        message = "nftables: chain ${tname}/${cname}: type, hook, and priority must all be set for a base chain";
      }) table.chains
    ) cfg.tables);
  in
    lib.mkIf (cfg.tables != {}) {
      assertions = baseChainAssertions;
      networking.nftables = {
        enable = true;
        checkRuleset = false;
        inherit ruleset;
      };
    };
}
