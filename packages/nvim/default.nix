{ pkgs }:

pkgs.neovim.override {
  configure = {
    customLuaRC = builtins.readFile ./init.lua;

    packages.myPlugins = with pkgs.vimPlugins; {
      start = [
        # Tree-sitter with all grammars
        nvim-treesitter.withAllGrammars
      ];
      opt = [ ];
    };
  };
}
