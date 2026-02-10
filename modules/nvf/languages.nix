{
  path = ["psyclyx" "nixos" "programs" "nvf" "languages"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {...}: {
    vim = {
      # ── Treesitter ────────────────────────────────────────────────
      treesitter = {
        enable = true;
        fold = true;
        context.enable = true;
      };

      # ── LSP ───────────────────────────────────────────────────────
      lsp = {
        enable = true;
        formatOnSave = true;
        lspSignature.enable = true;
        lightbulb.enable = true;
        inlayHints.enable = true;
        trouble.enable = true;
      };

      visuals.fidget-nvim.enable = true;
      visuals.rainbow-delimiters.enable = true;
      visuals.highlight-undo.enable = true;

      diagnostics.enable = true;

      ui.nvim-ufo.enable = true;
      ui.fastaction.enable = true;

      notes.todo-comments.enable = true;

      # ── Languages ─────────────────────────────────────────────────
      languages = {
        enableFormat = true;
        enableTreesitter = true;
        enableExtraDiagnostics = true;

        nix.enable = true;
        rust = {
          enable = true;
          crates.enable = true;
        };
        clojure.enable = true;
        zig = {
          enable = true;
          dap.enable = true;
        };
        lua.enable = true;
        ts.enable = true;
        clang.enable = true;
        bash.enable = true;
        markdown.enable = true;
        css.enable = true;
        html.enable = true;
      };

      # ── REPL ──────────────────────────────────────────────────────
      repl.conjure.enable = true;

      # ── Git ───────────────────────────────────────────────────────
      git.vim-fugitive.enable = true;
      git.gitsigns.enable = true;
      git.git-conflict = {
        enable = true;
        mappings = {
          ours = "<leader>gxo";
          theirs = "<leader>gxt";
          both = "<leader>gxb";
          none = "<leader>gx0";
        };
      };
      git.gitlinker-nvim.enable = true;

      utility.direnv.enable = true;
      utility.sleuth.enable = true;
      utility.diffview-nvim.enable = true;
      utility.outline.aerial-nvim.enable = true;
      utility.undotree.enable = true;
      utility.yanky-nvim = {
        enable = true;
        setupOpts.ring.storage = "shada";
      };

      terminal.toggleterm = {
        enable = true;
        setupOpts.direction = "horizontal";
      };

      # ── AI assistant ──────────────────────────────────────────────
      assistant.avante-nvim = {
        enable = true;
        setupOpts = {
          provider = "claude";
          behaviour = {
            auto_set_keymaps = true;
            auto_set_highlight_group = true;
            minimize_diff = true;
            enable_token_counting = true;
          };
          windows = {
            position = "right";
            width = 30;
            wrap = true;
          };
        };
      };
    };
  };
}
