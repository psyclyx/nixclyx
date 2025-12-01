{ pkgs }:

pkgs.neovim.override {
  configure = {
    customRC = '''';

    packages.myPlugins = with pkgs.vimPlugins; {
      start = [
        # Tree-sitter with all grammars
        nvim-treesitter.withAllGrammars
      ];
      opt = [ ];
    };
  };

  extraLuaConfig = builtins.readFile ./init.lua;
}
