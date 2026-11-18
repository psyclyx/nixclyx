{
  path = ["psyclyx" "home" "programs" "weft"];
  description = "weft, the text editor, running its reference config";
  options = {lib, ...}: {
    configFile = lib.mkOption {
      type = lib.types.str;
      default = "config.js";
      example = "helix.js";
      description = ''
        Which of weft's shipped configs (its config/ directory) to run:
        `config.js` (vim, the reference), `helix.js` or `ide.js`.
      '';
    };
  };
  config = {cfg, ...}: {
    # weft's own home-manager module (imported in ../default.nix) wraps
    # pkgs.weft (from weft's producer overlay) with --config, the grammars
    # the reference config registers, and its language servers on PATH.
    programs.weft = {
      enable = true;
      inherit (cfg) configFile;
    };
  };
}
