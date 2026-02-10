{
  path = ["psyclyx" "nixos" "programs" "nvf"];
  description = "nvf (neovim)";
  config = {...}: {
    vim = {
      globals = {
        mapleader = " ";
        maplocalleader = " m";
      };

      options = {
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        ignorecase = true;
        smartcase = true;
        number = true;
        relativenumber = true;
        cursorline = true;
        wrap = false;
        scrolloff = 3;
        hidden = true;
        termguicolors = true;
        signcolumn = "yes";
        colorcolumn = "80";
        showmode = false;
        splitbelow = true;
        splitright = true;
        updatetime = 250;
      };

      clipboard = {
        enable = true;
        registers = "unnamedplus";
        providers.wl-copy.enable = true;
      };
      searchCase = "smart";
      hideSearchHighlight = true;
      preventJunkFiles = true;
      undoFile.enable = true;
      syntaxHighlighting = true;
      lineNumberMode = "relNumber";
      spellcheck.enable = true;

      theme = {
        enable = true;
      };
    };
  };
}
