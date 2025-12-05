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

      extraLuaConfig = builtins.readFile ./init.lua;

      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
      ];
    };
  };
}
