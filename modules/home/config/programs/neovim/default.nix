{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
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

      defaultEditor = mkDefault cfg.defaultEditor;

      plugins = [ pkgs.vimPlugins.nvim-tree-sitter.withAllGrammars ];

      vimdiffAlias = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    };
  };
}
