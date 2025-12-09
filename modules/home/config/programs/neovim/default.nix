{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;
  cfg = config.psyclyx.programs.neovim;
in
{
  options = {
    psyclyx.programs.neovim = {
      enable = mkEnableOption "neovim text editor";
      defaultEditor = mkEnableOption "default editor";
    };
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = cfg.defaultEditor;

      # Add LSP servers
      extraPackages = with pkgs; [
        nil # Nix LSP
        lua-language-server # Lua LSP
        rust-analyzer # Rust LSP
        clang-tools # C/C++ LSP (clangd)
        nodePackages.typescript-language-server # TypeScript/JS LSP
        clojure-lsp # Clojure/ClojureScript LSP
        zls # Zig LSP
      ];

      # Just load init.lua - it will require() everything else
      extraLuaConfig = builtins.readFile ./nvim/init.lua;

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
