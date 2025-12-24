local map = vim.keymap.set
local opts = { buffer = 0 }

map('n', '<LocalLeader>r', '<Cmd>luafile %<CR>', vim.tbl_extend('force', opts, { desc = 'Run Lua file' }))
map('n', '<LocalLeader>s', '<Cmd>source %<CR>', vim.tbl_extend('force', opts, { desc = 'Source Lua file' }))
