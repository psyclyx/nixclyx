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
  home.packages = [pkgs.psyclyx.nvim];
  home.sessionVariables.EDITOR = "nvim";
};
}
