{
  path = ["psyclyx" "nixos" "programs" "nvf" "languages"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {lib, ...}: {
    vim = {
      # ── Completion ─────────────────────────────────────────────────
      autocomplete.blink-cmp = {
        enable = true;
        mappings = {
          complete = "<C-Space>";
          confirm = "<CR>";
          next = "<Tab>";
          previous = "<S-Tab>";
          close = "<C-e>";
          scrollDocsUp = "<C-u>";
          scrollDocsDown = "<C-d>";
        };
        friendly-snippets.enable = true;
        setupOpts = {
          sources.default = ["lsp" "path" "snippets" "buffer"];
          completion.documentation.auto_show = true;
          completion.documentation.auto_show_delay_ms = 100;
          fuzzy.implementation = "prefer_rust";
          signature.enabled = true;
        };
      };

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
        lightbulb.enable = true;
        inlayHints.enable = true;
        trouble.enable = true;
      };

      visuals.fidget-nvim.enable = true;
      visuals.rainbow-delimiters.enable = true;
      visuals.highlight-undo = {
        enable = true;
        setupOpts = {
          ignored_filetypes = [
            # defaults
            "neo-tree" "fugitive" "TelescopePrompt" "mason" "lazy"
            # ui buffers that flash on render
            "ministarter"
          ];
          ignore_cb = lib.generators.mkLuaInline ''
            function(buf)
              local bo = vim.bo[buf]
              if bo.buftype ~= "" then return true end
              if not bo.modifiable then return true end
              local name = vim.api.nvim_buf_get_name(buf)
              if name:match("conjure%-log%-") then return true end
              return false
            end
          '';
        };
      };
      visuals.hlargs-nvim.enable = true;

      diagnostics.enable = true;

      debugger.nvim-dap = {
        enable = true;
        ui.enable = true;
      };

      ui.nvim-ufo.enable = true;
      ui.fastaction.enable = true;
      ui.smartcolumn = {
        enable = true;
        setupOpts.colorcolumn = "80";
      };

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
          dap.enable = true;
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
        markdown = {
          enable = true;
          extensions.render-markdown-nvim.enable = true;
        };
        css.enable = true;
        html.enable = true;
      };

      # ── REPL ──────────────────────────────────────────────────────
      repl.conjure.enable = true;
      globals.conjure = {
        filetype.clojure = "conjure.client.clojure.nrepl";
        client.clojure.nrepl.connection.auto_repl = {
          cmd = "clj -Sdeps '{:deps {nrepl/nrepl {:mvn/version \"1.3.0\"} cider/cider-nrepl {:mvn/version \"0.50.2\"}}}' -M -m nrepl.cmdline --port $port --middleware '[cider.nrepl/cider-middleware]'";
        };
      };

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

      utility.smart-splits.enable = true;
      utility.mkdir.enable = true;
      utility.direnv.enable = true;
      utility.sleuth.enable = true;
      utility.diffview-nvim.enable = true;
      utility.outline.aerial-nvim.enable = true;
      utility.undotree.enable = true;
      utility.yanky-nvim = {
        enable = true;
        setupOpts.ring.storage = "sqlite";
      };

      navigation.harpoon = {
        enable = true;
        mappings = {
          markFile = "<leader>a";
          listMarks = "<leader>e";
          file1 = "<leader>1";
          file2 = "<leader>2";
          file3 = "<leader>3";
          file4 = "<leader>4";
        };
      };

      ui.noice = {
        enable = true;
        setupOpts = {
          presets = {
            bottom_search = true;
            command_palette = true;
            long_message_to_split = true;
            lsp_doc_border = true;
          };
        };
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
