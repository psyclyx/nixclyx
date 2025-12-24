{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.home.programs.neovim;
in
{
  options = {
    psyclyx.home.programs.neovim = {
      enable = lib.mkEnableOption "neovim text editor";
      defaultEditor = lib.mkEnableOption "default editor";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = cfg.defaultEditor;
      extraLuaConfig = builtins.readFile ./nvim/init.lua;
      extraPackages = [
        pkgs.clang-tools
        pkgs.clojure-lsp
        pkgs.lua-language-server
        pkgs.nil
        pkgs.nodePackages.typescript-language-server
        pkgs.rust-analyzer
        pkgs.zls
      ];

      plugins =
        let
          inherit (pkgs) vimPlugins;
        in
        [
          vimPlugins.nvim-treesitter.withAllGrammars
          vimPlugins.mini-nvim
          vimPlugins.conjure
        ];
    };

    xdg.configFile = {
      "nvim/lua" = {
        source = ./nvim/lua;
        recursive = true;
      };

      "nvim/ftplugin" = {
        source = ./nvim/ftplugin;
        recursive = true;
      };
    };
  };
}
