{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.neovim;
in
{
  options = {
    psyclyx.programs.neovim = {
      enable = lib.mkEnableOption "neovim text editor";
      defaultEditor = lib.mkEnableOption "default editor";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = cfg.defaultEditor;

      extraLuaConfig = builtins.readFile ./nvim/init.lua;

      extraPackages = with pkgs; [
        nil
        lua-language-server
        rust-analyzer
        clang-tools
        nodePackages.typescript-language-server # TypeScript/JS LSP
        clojure-lsp
        zls
      ];

      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
        mini-nvim
        conjure
      ];
    };

    # Symlink contents of nvim/ directory to ~/.config/nvim/
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
