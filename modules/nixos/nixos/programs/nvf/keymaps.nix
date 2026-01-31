{
  config,
  lib,
  ...
}: {
  config.programs.nvf.settings.vim = {
    keymaps = [
      # ── Top-level shortcuts ──
      {key = "<leader><leader>"; mode = ["n"]; action = "<cmd>Pick files<CR>"; silent = true; desc = "Find files";}
      {key = "<leader>."; mode = ["n"]; action = "<cmd>lua MiniFiles.open()<CR>"; silent = true; desc = "File explorer";}
      {key = "<leader>,"; mode = ["n"]; action = "<cmd>Pick buffers<CR>"; silent = true; desc = "Switch buffer";}
      {key = "<leader>/"; mode = ["n"]; action = "<cmd>Pick grep_live<CR>"; silent = true; desc = "Search project";}
      {key = "<leader>:"; mode = ["n"]; action = ":"; desc = "Command mode";}

      # ── Buffers (b) ──
      {key = "<leader>bb"; mode = ["n"]; action = "<cmd>Pick buffers<CR>"; silent = true; desc = "Switch buffer";}
      {key = "<leader>bd"; mode = ["n"]; action = "<cmd>lua MiniBufremove.delete()<CR>"; silent = true; desc = "Delete buffer";}
      {key = "<leader>bD"; mode = ["n"]; action = "<cmd>lua MiniBufremove.delete(0, true)<CR>"; silent = true; desc = "Force delete buffer";}
      {key = "<leader>bn"; mode = ["n"]; action = "<cmd>bnext<CR>"; silent = true; desc = "Next buffer";}
      {key = "<leader>bp"; mode = ["n"]; action = "<cmd>bprevious<CR>"; silent = true; desc = "Previous buffer";}
      {key = "<leader>bN"; mode = ["n"]; action = "<cmd>enew<CR>"; silent = true; desc = "New buffer";}
      {key = "<leader>bs"; mode = ["n"]; action = "<cmd>Pick buf_lines<CR>"; silent = true; desc = "Search in buffer";}

      # ── Files (f) ──
      {key = "<leader>ff"; mode = ["n"]; action = "<cmd>Pick files<CR>"; silent = true; desc = "Find file";}
      {key = "<leader>fr"; mode = ["n"]; action = "<cmd>Pick oldfiles<CR>"; silent = true; desc = "Recent files";}
      {key = "<leader>fR"; mode = ["n"]; action = "<cmd>Pick visit_paths<CR>"; silent = true; desc = "Recent paths (visits)";}
      {key = "<leader>fs"; mode = ["n"]; action = "<cmd>w<CR>"; silent = true; desc = "Save file";}
      {key = "<leader>fS"; mode = ["n"]; action = "<cmd>wa<CR>"; silent = true; desc = "Save all files";}
      {key = "<leader>ft"; mode = ["n"]; action = "<cmd>lua MiniFiles.open()<CR>"; silent = true; desc = "File tree";}
      {key = "<leader>fe"; mode = ["n"]; action = "<cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>"; silent = true; desc = "Find file in tree";}
      {key = "<leader>fy"; mode = ["n"]; action = "<cmd>let @+ = expand(\"%:p\")<CR>"; silent = true; desc = "Yank file path";}

      # ── Git (g) ──
      {key = "<leader>gg"; mode = ["n"]; action = "<cmd>lua MiniGit.show_at_cursor()<CR>"; silent = true; desc = "Show git info";}
      {key = "<leader>gd"; mode = ["n"]; action = "<cmd>lua MiniDiff.toggle_overlay()<CR>"; silent = true; desc = "Toggle diff overlay";}
      {key = "<leader>gD"; mode = ["n"]; action = "<cmd>lua MiniDiff.toggle()<CR>"; silent = true; desc = "Toggle diff signs";}
      {key = "<leader>gs"; mode = ["n"]; action = "<cmd>Pick git_files<CR>"; silent = true; desc = "Git status";}
      {key = "<leader>gc"; mode = ["n"]; action = "<cmd>Pick git_commits<CR>"; silent = true; desc = "Git commits";}
      {key = "<leader>gb"; mode = ["n"]; action = "<cmd>Pick git_branches<CR>"; silent = true; desc = "Git branches";}
      {key = "<leader>gh"; mode = ["n"]; action = "<cmd>Pick git_hunks<CR>"; silent = true; desc = "Git hunks";}

      # ── Help (h) ──
      {key = "<leader>hh"; mode = ["n"]; action = "<cmd>Pick help<CR>"; silent = true; desc = "Help tags";}
      {key = "<leader>hk"; mode = ["n"]; action = "<cmd>Pick keymaps<CR>"; silent = true; desc = "Search keymaps";}
      {key = "<leader>hm"; mode = ["n"]; action = "<cmd>Pick commands<CR>"; silent = true; desc = "Search commands";}
      {key = "<leader>hn"; mode = ["n"]; action = "<cmd>lua MiniNotify.show_history()<CR>"; silent = true; desc = "Show notifications";}

      # ── LSP / Code (c) ──
      {key = "<leader>cd"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.definition()<CR>"; silent = true; desc = "Go to definition";}
      {key = "<leader>cD"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.type_definition()<CR>"; silent = true; desc = "Type definition";}
      {key = "<leader>cr"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.references()<CR>"; silent = true; desc = "Find references";}
      {key = "<leader>ci"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.implementation()<CR>"; silent = true; desc = "Go to implementation";}
      {key = "<leader>cn"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.rename()<CR>"; silent = true; desc = "Rename symbol";}
      {key = "<leader>ca"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.code_action()<CR>"; silent = true; desc = "Code action";}
      {key = "<leader>cf"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.format()<CR>"; silent = true; desc = "Format";}
      {key = "<leader>ch"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.hover()<CR>"; silent = true; desc = "Hover docs";}
      {key = "<leader>ck"; mode = ["n"]; action = "<cmd>lua vim.lsp.buf.signature_help()<CR>"; silent = true; desc = "Signature help";}
      {key = "<leader>ce"; mode = ["n"]; action = "<cmd>lua vim.diagnostic.open_float()<CR>"; silent = true; desc = "Show diagnostics";}
      {key = "<leader>c["; mode = ["n"]; action = "<cmd>lua vim.diagnostic.goto_prev()<CR>"; silent = true; desc = "Previous diagnostic";}
      {key = "<leader>c]"; mode = ["n"]; action = "<cmd>lua vim.diagnostic.goto_next()<CR>"; silent = true; desc = "Next diagnostic";}

      # ── Project (p) ──
      {key = "<leader>pf"; mode = ["n"]; action = "<cmd>Pick files<CR>"; silent = true; desc = "Find file in project";}
      {key = "<leader>pg"; mode = ["n"]; action = "<cmd>Pick grep_live<CR>"; silent = true; desc = "Grep in project";}
      {key = "<leader>ps"; mode = ["n"]; action = "<cmd>Pick grep pattern=\"<cword>\"<CR>"; silent = true; desc = "Search word in project";}

      # ── Search (s) ──
      {key = "<leader>ss"; mode = ["n"]; action = "<cmd>Pick grep_live<CR>"; silent = true; desc = "Live grep";}
      {key = "<leader>sw"; mode = ["n"]; action = "<cmd>Pick grep pattern=\"<cword>\"<CR>"; silent = true; desc = "Search word under cursor";}
      {key = "<leader>sb"; mode = ["n"]; action = "<cmd>Pick buf_lines<CR>"; silent = true; desc = "Search in buffer";}
      {key = "<leader>sr"; mode = ["n"]; action = "<cmd>Pick resume<CR>"; silent = true; desc = "Resume last search";}

      # ── Quit (q) ──
      {key = "<leader>qq"; mode = ["n"]; action = "<cmd>qa<CR>"; silent = true; desc = "Quit all";}
      {key = "<leader>qQ"; mode = ["n"]; action = "<cmd>qa!<CR>"; silent = true; desc = "Quit all (force)";}
      {key = "<leader>qs"; mode = ["n"]; action = "<cmd>lua MiniSessions.select('write')<CR>"; silent = true; desc = "Save session";}
      {key = "<leader>ql"; mode = ["n"]; action = "<cmd>lua MiniSessions.select('read')<CR>"; silent = true; desc = "Load session";}

      # ── Toggles (t) ──
      {key = "<leader>tw"; mode = ["n"]; action = "<cmd>set wrap!<CR>"; silent = true; desc = "Toggle wrap";}
      {key = "<leader>tn"; mode = ["n"]; action = "<cmd>set number!<CR>"; silent = true; desc = "Toggle line numbers";}
      {key = "<leader>tr"; mode = ["n"]; action = "<cmd>set relativenumber!<CR>"; silent = true; desc = "Toggle relative numbers";}
      {key = "<leader>ts"; mode = ["n"]; action = "<cmd>set spell!<CR>"; silent = true; desc = "Toggle spell check";}
      {key = "<leader>td"; mode = ["n"]; action = "<cmd>lua MiniDiff.toggle()<CR>"; silent = true; desc = "Toggle diff signs";}
      {key = "<leader>tm"; mode = ["n"]; action = "<cmd>lua MiniMap.toggle()<CR>"; silent = true; desc = "Toggle minimap";}

      # ── Windows (w) ──
      {key = "<leader>ww"; mode = ["n"]; action = "<C-w>w"; desc = "Other window";}
      {key = "<leader>wd"; mode = ["n"]; action = "<C-w>c"; desc = "Delete window";}
      {key = "<leader>w-"; mode = ["n"]; action = "<C-w>s"; desc = "Split horizontal";}
      {key = "<leader>w/"; mode = ["n"]; action = "<C-w>v"; desc = "Split vertical";}
      {key = "<leader>wh"; mode = ["n"]; action = "<C-w>h"; desc = "Move left";}
      {key = "<leader>wj"; mode = ["n"]; action = "<C-w>j"; desc = "Move down";}
      {key = "<leader>wk"; mode = ["n"]; action = "<C-w>k"; desc = "Move up";}
      {key = "<leader>wl"; mode = ["n"]; action = "<C-w>l"; desc = "Move right";}
      {key = "<leader>wH"; mode = ["n"]; action = "<C-w>H"; desc = "Move window left";}
      {key = "<leader>wJ"; mode = ["n"]; action = "<C-w>J"; desc = "Move window down";}
      {key = "<leader>wK"; mode = ["n"]; action = "<C-w>K"; desc = "Move window up";}
      {key = "<leader>wL"; mode = ["n"]; action = "<C-w>L"; desc = "Move window right";}
      {key = "<leader>w="; mode = ["n"]; action = "<C-w>="; desc = "Balance windows";}

      # ── Extras (x) ──
      {key = "<leader>xw"; mode = ["n"]; action = "<cmd>lua MiniTrailspace.trim()<CR>"; silent = true; desc = "Trim trailing whitespace";}
      {key = "<leader>xj"; mode = ["n"]; action = "<cmd>lua MiniSplitjoin.toggle()<CR>"; silent = true; desc = "Split/join";}
    ];
  };
}
