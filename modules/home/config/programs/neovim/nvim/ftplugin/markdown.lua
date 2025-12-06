local map = vim.keymap.set
local opts = { buffer = 0 }

map('n', '<LocalLeader>p', '<Cmd>!glow %<CR>', vim.tbl_extend('force', opts, { desc = 'Preview markdown' }))
