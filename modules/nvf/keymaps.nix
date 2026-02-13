{
  path = ["psyclyx" "nixos" "programs" "nvf" "keymaps"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {...}: {
    vim = {
      keymaps = [
        # ── Top-level shortcuts ──
        {
          key = "<leader><leader>";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.smart()<CR>";
          silent = true;
          desc = "Find files (smart)";
        }
        {
          key = "<leader>.";
          mode = ["n"];
          action = "<cmd>lua MiniFiles.open()<CR>";
          silent = true;
          desc = "File explorer";
        }
        {
          key = "<leader>,";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.buffers()<CR>";
          silent = true;
          desc = "Switch buffer";
        }
        {
          key = "<leader>/";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.grep()<CR>";
          silent = true;
          desc = "Search project";
        }
        {
          key = "<leader>:";
          mode = ["n"];
          action = ":";
          desc = "Command mode";
        }

        # ── Buffers (b) ──
        {
          key = "<leader>bd";
          mode = ["n"];
          action = "<cmd>lua Snacks.bufdelete()<CR>";
          silent = true;
          desc = "Delete buffer";
        }
        {
          key = "<leader>bD";
          mode = ["n"];
          action = "<cmd>lua Snacks.bufdelete({force=true})<CR>";
          silent = true;
          desc = "Force delete buffer";
        }
        {
          key = "<leader>bn";
          mode = ["n"];
          action = "<cmd>bnext<CR>";
          silent = true;
          desc = "Next buffer";
        }
        {
          key = "<leader>bp";
          mode = ["n"];
          action = "<cmd>bprevious<CR>";
          silent = true;
          desc = "Previous buffer";
        }
        {
          key = "<leader>bN";
          mode = ["n"];
          action = "<cmd>enew<CR>";
          silent = true;
          desc = "New buffer";
        }

        # ── Files (f) ──
        {
          key = "<leader>ff";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.files()<CR>";
          silent = true;
          desc = "Find files";
        }
        {
          key = "<leader>fr";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.recent()<CR>";
          silent = true;
          desc = "Recent files";
        }
        {
          key = "<leader>fR";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.recent({filter={cwd=true}})<CR>";
          silent = true;
          desc = "Recent files (cwd)";
        }
        {
          key = "<leader>fs";
          mode = ["n"];
          action = "<cmd>w<CR>";
          silent = true;
          desc = "Save file";
        }
        {
          key = "<leader>fS";
          mode = ["n"];
          action = "<cmd>wa<CR>";
          silent = true;
          desc = "Save all files";
        }
        {
          key = "<leader>fe";
          mode = ["n"];
          action = "<cmd>lua MiniFiles.open((vim.fn.filereadable(vim.api.nvim_buf_get_name(0)) == 1) and vim.api.nvim_buf_get_name(0) or nil)<CR>";
          silent = true;
          desc = "Find file in tree";
        }
        {
          key = "<leader>fy";
          mode = ["n"];
          action = "<cmd>let @+ = expand(\"%:p\")<CR>";
          silent = true;
          desc = "Yank file path";
        }

        # ── Git (g) ──
        {
          key = "<leader>gg";
          mode = ["n"];
          action = "<cmd>Git<CR>";
          silent = true;
          desc = "Fugitive status";
        }
        {
          key = "<leader>gl";
          mode = ["n"];
          action = "<cmd>Git log --oneline<CR>";
          silent = true;
          desc = "Git log";
        }
        {
          key = "<leader>gp";
          mode = ["n"];
          action = "<cmd>Git push<CR>";
          silent = true;
          desc = "Git push";
        }
        {
          key = "<leader>gP";
          mode = ["n"];
          action = "<cmd>Git pull<CR>";
          silent = true;
          desc = "Git pull";
        }
        {
          key = "<leader>gB";
          mode = ["n"];
          action = "<cmd>Git blame<CR>";
          silent = true;
          desc = "Git blame";
        }
        {
          key = "<leader>gs";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.git_status()<CR>";
          silent = true;
          desc = "Git status";
        }
        {
          key = "<leader>gc";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.git_log()<CR>";
          silent = true;
          desc = "Git commits";
        }
        {
          key = "<leader>gb";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.git_branches()<CR>";
          silent = true;
          desc = "Git branches";
        }
        {
          key = "<leader>gh";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.git_diff()<CR>";
          silent = true;
          desc = "Git hunks";
        }

        # ── Git hunks (gitsigns) ──
        {
          key = "<leader>ga";
          mode = ["n" "v"];
          action = "<cmd>Gitsigns stage_hunk<CR>";
          silent = true;
          desc = "Stage hunk";
        }
        {
          key = "<leader>gr";
          mode = ["n" "v"];
          action = "<cmd>Gitsigns reset_hunk<CR>";
          silent = true;
          desc = "Reset hunk";
        }
        {
          key = "<leader>gu";
          mode = ["n"];
          action = "<cmd>Gitsigns undo_stage_hunk<CR>";
          silent = true;
          desc = "Undo stage hunk";
        }
        {
          key = "<leader>gH";
          mode = ["n"];
          action = "<cmd>Gitsigns preview_hunk<CR>";
          silent = true;
          desc = "Preview hunk";
        }
        {
          key = "<leader>gR";
          mode = ["n"];
          action = "<cmd>Gitsigns reset_buffer<CR>";
          silent = true;
          desc = "Reset buffer";
        }

        # ── Gitlinker ──
        {
          key = "<leader>gy";
          mode = ["n" "v"];
          action = "<cmd>GitLink<CR>";
          silent = true;
          desc = "Copy git permalink";
        }

        # ── Diffview ──
        {
          key = "<leader>gv";
          mode = ["n"];
          action = "<cmd>DiffviewOpen<CR>";
          silent = true;
          desc = "Diffview open";
        }
        {
          key = "<leader>gV";
          mode = ["n"];
          action = "<cmd>DiffviewClose<CR>";
          silent = true;
          desc = "Diffview close";
        }
        {
          key = "<leader>gf";
          mode = ["n"];
          action = "<cmd>DiffviewFileHistory %<CR>";
          silent = true;
          desc = "File history (diffview)";
        }

        # ── Help (h) ──
        {
          key = "<leader>hh";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.help()<CR>";
          silent = true;
          desc = "Help tags";
        }
        {
          key = "<leader>hk";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.keymaps()<CR>";
          silent = true;
          desc = "Search keymaps";
        }
        {
          key = "<leader>hm";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.commands()<CR>";
          silent = true;
          desc = "Search commands";
        }
        {
          key = "<leader>hn";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.notifications()<CR>";
          silent = true;
          desc = "Notification history";
        }

        # ── LSP / Code (c) ──
        {
          key = "<leader>cd";
          mode = ["n"];
          action = "<cmd>lua vim.lsp.buf.definition()<CR>";
          silent = true;
          desc = "Go to definition";
        }
        {
          key = "<leader>cD";
          mode = ["n"];
          action = "<cmd>lua vim.lsp.buf.type_definition()<CR>";
          silent = true;
          desc = "Type definition";
        }
        {
          key = "<leader>cr";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.lsp_references()<CR>";
          silent = true;
          desc = "Find references";
        }
        {
          key = "<leader>ci";
          mode = ["n"];
          action = "<cmd>lua vim.lsp.buf.implementation()<CR>";
          silent = true;
          desc = "Go to implementation";
        }
        {
          key = "<leader>cn";
          mode = ["n"];
          action = "<cmd>lua vim.lsp.buf.rename()<CR>";
          silent = true;
          desc = "Rename symbol";
        }
        {
          key = "<leader>ca";
          mode = ["n" "v"];
          action = "<cmd>lua vim.lsp.buf.code_action()<CR>";
          silent = true;
          desc = "Code action";
        }
        {
          key = "<leader>cf";
          mode = ["n" "v"];
          action = "<cmd>lua vim.lsp.buf.format()<CR>";
          silent = true;
          desc = "Format";
        }
        {
          key = "<leader>ch";
          mode = ["n"];
          action = "<cmd>lua vim.lsp.buf.hover()<CR>";
          silent = true;
          desc = "Hover docs";
        }
        {
          key = "<leader>ck";
          mode = ["n"];
          action = "<cmd>lua vim.lsp.buf.signature_help()<CR>";
          silent = true;
          desc = "Signature help";
        }
        {
          key = "<leader>cs";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.lsp_symbols()<CR>";
          silent = true;
          desc = "Document symbols";
        }
        {
          key = "<leader>cS";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.lsp_workspace_symbols()<CR>";
          silent = true;
          desc = "Workspace symbols";
        }
        {
          key = "<leader>ce";
          mode = ["n"];
          action = "<cmd>lua vim.diagnostic.open_float()<CR>";
          silent = true;
          desc = "Show diagnostics";
        }
        {
          key = "<leader>c[";
          mode = ["n"];
          action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
          silent = true;
          desc = "Previous diagnostic";
        }
        {
          key = "<leader>c]";
          mode = ["n"];
          action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
          silent = true;
          desc = "Next diagnostic";
        }

        # ── Debug (d) ──
        {
          key = "<leader>dc";
          mode = ["n"];
          action = "<cmd>lua require('dap').continue()<CR>";
          silent = true;
          desc = "Continue";
        }
        {
          key = "<leader>ds";
          mode = ["n"];
          action = "<cmd>lua require('dap').step_over()<CR>";
          silent = true;
          desc = "Step over";
        }
        {
          key = "<leader>di";
          mode = ["n"];
          action = "<cmd>lua require('dap').step_into()<CR>";
          silent = true;
          desc = "Step into";
        }
        {
          key = "<leader>do";
          mode = ["n"];
          action = "<cmd>lua require('dap').step_out()<CR>";
          silent = true;
          desc = "Step out";
        }
        {
          key = "<leader>db";
          mode = ["n"];
          action = "<cmd>lua require('dap').toggle_breakpoint()<CR>";
          silent = true;
          desc = "Toggle breakpoint";
        }
        {
          key = "<leader>dB";
          mode = ["n"];
          action = "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Condition: '))<CR>";
          silent = true;
          desc = "Conditional breakpoint";
        }
        {
          key = "<leader>dr";
          mode = ["n"];
          action = "<cmd>lua require('dap').repl.open()<CR>";
          silent = true;
          desc = "Open REPL";
        }
        {
          key = "<leader>dl";
          mode = ["n"];
          action = "<cmd>lua require('dap').run_last()<CR>";
          silent = true;
          desc = "Run last";
        }
        {
          key = "<leader>du";
          mode = ["n"];
          action = "<cmd>lua require('dapui').toggle()<CR>";
          silent = true;
          desc = "Toggle DAP UI";
        }
        {
          key = "<leader>de";
          mode = ["n" "v"];
          action = "<cmd>lua require('dapui').eval()<CR>";
          silent = true;
          desc = "Evaluate expression";
        }

        # ── Search (s) ──
        {
          key = "<leader>sg";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.grep()<CR>";
          silent = true;
          desc = "Grep";
        }
        {
          key = "<leader>sw";
          mode = ["n" "v"];
          action = "<cmd>lua Snacks.picker.grep_word()<CR>";
          silent = true;
          desc = "Search word under cursor";
        }
        {
          key = "<leader>sb";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.lines()<CR>";
          silent = true;
          desc = "Search in buffer";
        }
        {
          key = "<leader>sr";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.resume()<CR>";
          silent = true;
          desc = "Resume last search";
        }
        {
          key = "<leader>sd";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.diagnostics()<CR>";
          silent = true;
          desc = "Search diagnostics";
        }
        {
          key = "<leader>st";
          mode = ["n"];
          action = "<cmd>TodoQuickFix<CR>";
          silent = true;
          desc = "Search TODOs";
        }
        {
          key = "<leader>sm";
          mode = ["n"];
          action = "<cmd>lua Snacks.picker.marks()<CR>";
          silent = true;
          desc = "Search marks";
        }

        # ── Quit (q) ──
        {
          key = "<leader>qq";
          mode = ["n"];
          action = "<cmd>qa<CR>";
          silent = true;
          desc = "Quit all";
        }
        {
          key = "<leader>qQ";
          mode = ["n"];
          action = "<cmd>qa!<CR>";
          silent = true;
          desc = "Quit all (force)";
        }
        {
          key = "<leader>qs";
          mode = ["n"];
          action = "<cmd>lua MiniSessions.select('write')<CR>";
          silent = true;
          desc = "Save session";
        }
        {
          key = "<leader>ql";
          mode = ["n"];
          action = "<cmd>lua MiniSessions.select('read')<CR>";
          silent = true;
          desc = "Load session";
        }

        # ── Toggles (t) ──
        {
          key = "<leader>tw";
          mode = ["n"];
          action = "<cmd>set wrap!<CR>";
          silent = true;
          desc = "Toggle wrap";
        }
        {
          key = "<leader>tn";
          mode = ["n"];
          action = "<cmd>set number!<CR>";
          silent = true;
          desc = "Toggle line numbers";
        }
        {
          key = "<leader>tr";
          mode = ["n"];
          action = "<cmd>set relativenumber!<CR>";
          silent = true;
          desc = "Toggle relative numbers";
        }
        {
          key = "<leader>ts";
          mode = ["n"];
          action = "<cmd>set spell!<CR>";
          silent = true;
          desc = "Toggle spell check";
        }
        {
          key = "<leader>tm";
          mode = ["n"];
          action = "<cmd>lua MiniMap.toggle()<CR>";
          silent = true;
          desc = "Toggle minimap";
        }
        {
          key = "<leader>tb";
          mode = ["n"];
          action = "<cmd>Gitsigns toggle_current_line_blame<CR>";
          silent = true;
          desc = "Toggle line blame";
        }
        {
          key = "<leader>tu";
          mode = ["n"];
          action = "<cmd>UndotreeToggle<CR>";
          silent = true;
          desc = "Toggle undo tree";
        }
        {
          key = "<leader>to";
          mode = ["n"];
          action = "<cmd>AerialToggle<CR>";
          silent = true;
          desc = "Toggle code outline";
        }

        # ── Open (o) ──
        {
          key = "<leader>ot";
          mode = ["n"];
          action = "<cmd>ToggleTerm<CR>";
          silent = true;
          desc = "Toggle terminal";
        }

        # ── Windows (w) ──
        {
          key = "<leader>ww";
          mode = ["n"];
          action = "<C-w>w";
          desc = "Other window";
        }
        {
          key = "<leader>wd";
          mode = ["n"];
          action = "<C-w>c";
          desc = "Delete window";
        }
        {
          key = "<leader>w-";
          mode = ["n"];
          action = "<C-w>s";
          desc = "Split horizontal";
        }
        {
          key = "<leader>w/";
          mode = ["n"];
          action = "<C-w>v";
          desc = "Split vertical";
        }
        {
          key = "<leader>w=";
          mode = ["n"];
          action = "<C-w>=";
          desc = "Balance windows";
        }

        # ── Yanky ──
        {
          key = "p";
          mode = ["n" "x"];
          action = "<Plug>(YankyPutAfter)";
          desc = "Put after (yanky)";
        }
        {
          key = "P";
          mode = ["n" "x"];
          action = "<Plug>(YankyPutBefore)";
          desc = "Put before (yanky)";
        }
        {
          key = "<C-p>";
          mode = ["n"];
          action = "<Plug>(YankyPreviousEntry)";
          desc = "Yanky previous";
        }
        {
          key = "<C-n>";
          mode = ["n"];
          action = "<Plug>(YankyNextEntry)";
          desc = "Yanky next";
        }

        # ── Extras / Diagnostics (x) ──
        {
          key = "<leader>xx";
          mode = ["n"];
          action = "<cmd>Trouble diagnostics toggle<CR>";
          silent = true;
          desc = "All diagnostics";
        }
        {
          key = "<leader>xX";
          mode = ["n"];
          action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
          silent = true;
          desc = "Buffer diagnostics";
        }
        {
          key = "<leader>xl";
          mode = ["n"];
          action = "<cmd>Trouble loclist toggle<CR>";
          silent = true;
          desc = "Location list";
        }
        {
          key = "<leader>xq";
          mode = ["n"];
          action = "<cmd>Trouble qflist toggle<CR>";
          silent = true;
          desc = "Quickfix list";
        }
        {
          key = "<leader>xw";
          mode = ["n"];
          action = "<cmd>lua MiniTrailspace.trim()<CR>";
          silent = true;
          desc = "Trim trailing whitespace";
        }
        {
          key = "<leader>xj";
          mode = ["n"];
          action = "<cmd>lua MiniSplitjoin.toggle()<CR>";
          silent = true;
          desc = "Split/join";
        }
      ];
    };
  };
}
