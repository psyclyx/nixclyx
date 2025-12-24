local map = vim.keymap.set
local opts = { buffer = 0 }

map('n', '<LocalLeader>r', '<Cmd>!cargo run<CR>', vim.tbl_extend('force', opts, { desc = 'Cargo run' }))
map('n', '<LocalLeader>b', '<Cmd>!cargo build<CR>', vim.tbl_extend('force', opts, { desc = 'Cargo build' }))
map('n', '<LocalLeader>t', '<Cmd>!cargo test<CR>', vim.tbl_extend('force', opts, { desc = 'Cargo test' }))
map('n', '<LocalLeader>c', '<Cmd>!cargo check<CR>', vim.tbl_extend('force', opts, { desc = 'Cargo check' }))
