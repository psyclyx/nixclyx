local map = vim.keymap.set
local opts = { buffer = 0 }

map('n', '<LocalLeader>f', '<Cmd>!nixpkgs-fmt %<CR>', vim.tbl_extend('force', opts, { desc = 'Format Nix file' }))
map('n', '<LocalLeader>c', '<Cmd>!nix-instantiate --parse %<CR>', vim.tbl_extend('force', opts, { desc = 'Check Nix syntax' }))
map('n', '<LocalLeader>b', '<Cmd>!nix-build<CR>', vim.tbl_extend('force', opts, { desc = 'Build derivation' }))
