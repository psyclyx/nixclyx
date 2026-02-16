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
        formatOnSave = true;
        inlayHints.enable = true;
        trouble.enable = true;
        lightbulb.enable = true;
        lspkind.enable = true;
      };
      diagnostics = {
        enable = true;
      };
      filetree.neo-tree.enable = true;
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
        enableLSP = true;
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
        odin.enable = true;
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
        motion.precognition.enable = true;
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
        };
      };

      extraPlugins = {
        nvim-paredit = {
          package = pkgs.vimPlugins.nvim-paredit;
          setup = ''require("nvim-paredit").setup({})'';
        };
      };

      keymaps = [
        # neo-tree
        {
          mode = "n";
          key = "<leader>ee";
          action = "<cmd>Neotree toggle<cr>";
          desc = "Toggle file tree";
        }
        {
          mode = "n";
          key = "<leader>ef";
          action = "<cmd>Neotree reveal<cr>";
          desc = "Reveal current file";
        }
        {
          mode = "n";
          key = "<leader>fe";
          action = "<cmd>lua require('neo-tree.command').execute({ dir = vim.fn.expand('%:p:h'), reveal = true })<cr>";
          desc = "Browse current directory";
        }
        {
          mode = "n";
          key = "<leader>es";
          action = "<cmd>Neotree document_symbols<cr>";
          desc = "Document symbols";
        }
        {
          mode = "n";
          key = "<leader>eg";
          action = "<cmd>Neotree git_status<cr>";
          desc = "Git status tree";
        }
        {
          mode = "n";
          key = "<leader>eb";
          action = "<cmd>Neotree buffers<cr>";
          desc = "Buffer tree";
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
