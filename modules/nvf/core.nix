{
  path = ["psyclyx" "nixos" "programs" "nvf"];
  description = "nvf (neovim)";
  options = {lib, ...}: {
    anthropicKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing Anthropic API key (read at neovim startup)";
    };
    openrouterKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing OpenRouter API key (read at neovim startup)";
    };
  };
  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: {
    vim = {
      enableLuaLoader = true;

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
        timeoutlen = 300;
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
        name = "base16";
        transparent = true;
      };

      lsp = {
        enable = true;
        formatOnSave = true;
        inlayHints.enable = true;
        trouble.enable = true;
        lightbulb.enable = true;
        lspkind.enable = true;
      };
      diagnostics = {
        enable = true;
      };
      filetree.neo-tree.enable = false;
      binds = {
        whichKey = {
          enable = true;
          register = {
            "<leader>w" = "Windows";
            "<leader>b" = "Buffers";
            "<leader>f" = "Find";
            "<leader>s" = "Search";
            "<leader>q" = "Quit";
            "<leader>e" = "Explorer";
            "<leader>g" = "Git";
            "<leader>l" = "LSP";
            "<leader>u" = "Toggle";
            "<leader>a" = "AI (Avante)";
          };
        };
      };

      dashboard.alpha.enable = true;

      formatter.conform-nvim.enable = true;
      git.enable = true;
      telescope = {
        enable = true;
        setupOpts.defaults.vimgrep_arguments = [
          "${pkgs.ripgrep}/bin/rg"
          "--color=never"
          "--no-heading"
          "--with-filename"
          "--line-number"
          "--column"
          "--smart-case"
        ];
        extensions = [
          {
            name = "fzf";
            packages = [pkgs.vimPlugins.telescope-fzf-native-nvim];
            setup = {
              fzf = {
                fuzzy = true;
                override_generic_sorter = true;
                override_file_sorter = true;
                case_mode = "smart_case";
              };
            };
          }
        ];
      };
      autocomplete.blink-cmp = {
        enable = true;
        setupOpts = {
          signature.enabled = true;
          completion.documentation = {
            auto_show = true;
            auto_show_delay_ms = 100;
          };
        };
      };
      statusline.lualine.enable = true;

      languages = {
        enableDAP = true;
        enableExtraDiagnostics = true;
        enableFormat = true;
        enableTreesitter = true;
        assembly.enable = true;
        bash.enable = true;
        clojure.enable = true;
        clang.enable = true;
        haskell.enable = true;
        html.enable = true;
        java.enable = true;
        json.enable = true;
        julia.enable = true;
        just.enable = true;
        lua.enable = true;
        markdown.enable = true;
        nix.enable = true;
        ocaml.enable = true;
        # odin.enable = true; # disabled: ols broken with current nixpkgs (using-stmt)
        python.enable = true;
        rust = {
          enable = true;
          extensions.crates-nvim.enable = true;
        };
        sql.enable = true;
        ts.enable = true;
        wgsl.enable = true;
        yaml.enable = true;
        zig.enable = true;
      };

      treesitter = {
        autotagHtml = true;
        context.enable = true;
        fold = true;
        grammars = [pkgs.vimPlugins.nvim-treesitter-parsers.janet_simple];
        textobjects.enable = true;
      };
      ui = {
        borders = {
          enable = true;
          globalStyle = "single";
        };
        breadcrumbs = {
          enable = true;
          navbuddy.enable = true;
        };
        colorizer.enable = true;
        illuminate.enable = true;
        noice = {
          enable = true;
          setupOpts.lsp.signature.enabled = true;
        };
      };
      autopairs.nvim-autopairs.enable = true;
      comments.comment-nvim.enable = true;
      utility = {
        ccc.enable = true;
        direnv.enable = true;
        mkdir.enable = true;
        motion.precognition = {
          enable = true;
          setupOpts.startVisible = false;
        };
        multicursors.enable = true;
        surround.enable = true;
      };
      repl.conjure.enable = true;
      visuals = {
        rainbow-delimiters.enable = true;
      };
      assistant.avante-nvim = {
        enable = true;
        setupOpts = {
          provider = "claude";
          behaviour.auto_set_keymaps = true;
          hints.enabled = true;
          providers = {
            claude = {
              endpoint = "https://api.anthropic.com";
              model = "claude-opus-4-6";
              timeout = 30000;
              extra_request_body = {
                temperature = 0.75;
                max_tokens = 64000;
              };
            };
            claude-sonnet = {
              __inherited_from = "claude";
              model = "claude-sonnet-4-6";
            };
            openrouter = {
              __inherited_from = "openai";
              endpoint = "https://openrouter.ai/api/v1";
              api_key_name = "OPENROUTER_API_KEY";
              model = "anthropic/claude-sonnet-4-6";
            };
          };
        };
      };

      extraPlugins = {
        nvim-paredit = {
          package = pkgs.vimPlugins.nvim-paredit;
          setup = ''require("nvim-paredit").setup({})'';
        };
        mini-files = {
          package = pkgs.vimPlugins.mini-nvim;
          setup = ''require("mini.files").setup({})'';
        };
      };

      keymaps = [
        # mini.files
        {
          mode = "n";
          key = "<leader>fe";
          action = "<cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<cr>";
          desc = "File explorer (current file)";
        }
        {
          mode = "n";
          key = "<leader>ee";
          action = "<cmd>lua MiniFiles.open()<cr>";
          desc = "File explorer (cwd)";
        }

        # window management
        {
          mode = "n";
          key = "<leader>wv";
          action = "<cmd>vsplit<cr>";
          desc = "Vertical split";
        }
        {
          mode = "n";
          key = "<leader>ws";
          action = "<cmd>split<cr>";
          desc = "Horizontal split";
        }
        {
          mode = "n";
          key = "<leader>wd";
          action = "<cmd>close<cr>";
          desc = "Close window";
        }
        {
          mode = "n";
          key = "<leader>w=";
          action = "<C-w>=";
          desc = "Balance windows";
        }
        {
          mode = "n";
          key = "<leader>wh";
          action = "<C-w>h";
          desc = "Window left";
        }
        {
          mode = "n";
          key = "<leader>wj";
          action = "<C-w>j";
          desc = "Window down";
        }
        {
          mode = "n";
          key = "<leader>wk";
          action = "<C-w>k";
          desc = "Window up";
        }
        {
          mode = "n";
          key = "<leader>wl";
          action = "<C-w>l";
          desc = "Window right";
        }

        # buffer management
        {
          mode = "n";
          key = "<leader>bd";
          action = "<cmd>bdelete<cr>";
          desc = "Delete buffer";
        }
        {
          mode = "n";
          key = "<leader>bn";
          action = "<cmd>bnext<cr>";
          desc = "Next buffer";
        }
        {
          mode = "n";
          key = "<leader>bp";
          action = "<cmd>bprevious<cr>";
          desc = "Previous buffer";
        }
        {
          mode = "n";
          key = "<leader><tab>";
          action = "<cmd>b#<cr>";
          desc = "Last buffer";
        }

        # quit/session
        {
          mode = "n";
          key = "<leader>qq";
          action = "<cmd>qa<cr>";
          desc = "Quit all";
        }

        # buffers / grep
        {
          mode = "n";
          key = "<leader>,";
          action = "<cmd>Telescope buffers<cr>";
          desc = "Open buffers";
        }
        {
          mode = "n";
          key = "<leader>/";
          action = "<cmd>Telescope live_grep<cr>";
          desc = "Grep in project";
        }

        # search
        {
          mode = "n";
          key = "<leader>sc";
          action = "<cmd>nohlsearch<cr>";
          desc = "Clear highlights";
        }
        {
          mode = "n";
          key = "<leader>fo";
          action = "<cmd>Telescope oldfiles<cr>";
          desc = "Recent files";
        }
        {
          mode = "n";
          key = "<leader>fk";
          action = "<cmd>Telescope keymaps<cr>";
          desc = "Keybindings";
        }

        # quickfix
        {
          mode = "n";
          key = "]q";
          action = "<cmd>cnext<cr>";
          desc = "Next quickfix";
        }
        {
          mode = "n";
          key = "[q";
          action = "<cmd>cprev<cr>";
          desc = "Previous quickfix";
        }

        # toggles
        {
          mode = "n";
          key = "<leader>ui";
          action = "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>";
          desc = "Toggle inlay hints";
        }
        {
          mode = "n";
          key = "<leader>up";
          action = "<cmd>lua require('precognition').toggle()<cr>";
          desc = "Toggle precognition";
        }
      ];

      luaConfigRC.mini-files-keymaps = lib.nvim.dag.entryAnywhere ''
        local function mini_files_split(buf_id, direction)
          local rhs = function()
            local new_target_window
            vim.api.nvim_win_call(MiniFiles.get_target_window(), function()
              vim.cmd(direction .. " split")
              new_target_window = vim.api.nvim_get_current_win()
            end)
            MiniFiles.set_target_window(new_target_window)
            MiniFiles.go_in({ close_on_file = true })
          end
          local desc = direction:sub(1, 1):upper() .. direction:sub(2) .. " split"
          vim.keymap.set("n", direction == "horizontal" and "<C-x>" or "<C-v>", rhs, { buffer = buf_id, desc = desc })
        end

        vim.api.nvim_create_autocmd("User", {
          pattern = "MiniFilesBufferCreate",
          callback = function(args)
            local buf_id = args.data.buf_id
            vim.keymap.set("n", "<CR>", function()
              MiniFiles.go_in({ close_on_file = true })
            end, { buffer = buf_id, desc = "Open file and close explorer" })
            vim.keymap.set("n", "<Esc>", MiniFiles.close, { buffer = buf_id, desc = "Close explorer" })
            mini_files_split(buf_id, "horizontal")
            mini_files_split(buf_id, "vertical")
          end,
        })
      '';

      luaConfigRC.anthropic-key = lib.mkIf (cfg.anthropicKeyFile != null) (lib.nvim.dag.entryAnywhere ''
        local f = io.open("${cfg.anthropicKeyFile}", "r")
        if f then
          vim.env.ANTHROPIC_API_KEY = f:read("*a"):gsub("%s+$", "")
          f:close()
        end
      '');

      luaConfigRC.openrouter-key = lib.mkIf (cfg.openrouterKeyFile != null) (lib.nvim.dag.entryAnywhere ''
        local f = io.open("${cfg.openrouterKeyFile}", "r")
        if f then
          vim.env.OPENROUTER_API_KEY = f:read("*a"):gsub("%s+$", "")
          f:close()
        end
      '');
    };
  };
}
