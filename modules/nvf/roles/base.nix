{
  path = ["psyclyx" "nvf" "roles" "base"];
  description = "base nvf role";
  config = {lib, ...}: {
    psyclyx.nvf = {
      ai.enable = lib.mkDefault true;
      binds.enable = lib.mkDefault true;
      editor.enable = lib.mkDefault true;
      explorer.enable = lib.mkDefault true;
      languages.enable = lib.mkDefault true;
      lsp.enable = lib.mkDefault true;
      telescope.enable = lib.mkDefault true;
      ui.enable = lib.mkDefault true;
      utility.enable = lib.mkDefault true;
      vcs.enable = lib.mkDefault true;
    };
  };
}
