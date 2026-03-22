{
  path = ["psyclyx" "nvf" "editor"];
  description = "text editing behaviour";
  config = {pkgs, ...}: {
    vim = {
      enableLuaLoader = true;

      options = {
        shiftwidth = 2;
        tabstop = 2;

        ignorecase = true;
        smartcase = true;

        updatetime = 250;
        timeoutlen = 300;

        foldlevelstart = 99;
      };

      clipboard = {
        enable = true;
        registers = "unnamedplus";
        providers.wl-copy.enable = true;
      };

      searchCase = "smart";
      hideSearchHighlight = true;

      undoFile.enable = true;
      syntaxHighlighting = true;
      spellcheck.enable = true;

      autopairs.nvim-autopairs.enable = true;
      comments.comment-nvim.enable = true;
      repl.conjure.enable = true;

      extraPlugins.nvim-paredit = {
        package = pkgs.vimPlugins.nvim-paredit;
        setup = ''require("nvim-paredit").setup({})'';
      };
    };
  };
}
