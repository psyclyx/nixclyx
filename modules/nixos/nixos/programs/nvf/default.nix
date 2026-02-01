{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.programs.nvf;
in {
  imports = [
    ./languages.nix
    ./mini.nix
    ./keymaps.nix
  ];

  options = {
    psyclyx.nixos.programs.nvf = {
      enable = lib.mkEnableOption "nvf (neovim)";
    };
  };

  config = {
    programs.nvf = {
      enable = lib.mkIf cfg.enable true;
      settings.vim = {
        # ── Core options ──────────────────────────────────────────────
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

        clipboard.enable = true;
        searchCase = "smart";
        hideSearchHighlight = true;
        preventJunkFiles = true;
        undoFile.enable = true;
        syntaxHighlighting = true;
        lineNumberMode = "relNumber";
        spellcheck.enable = true;

        # ── Theme ─────────────────────────────────────────────────────
        theme = {
          enable = true;
        };
      };
    };
  };
}
