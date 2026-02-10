{
  path = ["psyclyx" "nixos" "programs" "nvf"];
  description = "nvf (neovim)";
  options = {lib, ...}: {
    anthropicKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing Anthropic API key (read at neovim startup)";
    };
  };
  config = {cfg, lib, ...}: {
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
        colorcolumn = "";
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

      luaConfigRC.anthropic-key = lib.mkIf (cfg.anthropicKeyFile != null) (lib.nvim.dag.entryAnywhere ''
        local f = io.open("${cfg.anthropicKeyFile}", "r")
        if f then
          vim.env.ANTHROPIC_API_KEY = f:read("*a"):gsub("%s+$", "")
          f:close()
        end
      '');
    };
  };
}
