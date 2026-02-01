{
  config,
  lib,
  ...
}: {
  config.programs.nvf.settings.vim = {
    # ── Treesitter ────────────────────────────────────────────────
    treesitter = {
      enable = true;
      fold = true;
    };

    # ── LSP ───────────────────────────────────────────────────────
    lsp = {
      enable = true;
      formatOnSave = true;
    };

    diagnostics.enable = true;

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
      zig.enable = true;
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
}
