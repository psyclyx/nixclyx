vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4
vim.opt_local.expandtab = true

vim.keymap.set('n', '<localleader>r', '<cmd>!zig build run<CR>', { buffer = true, desc = 'Run Zig build' })
vim.keymap.set('n', '<localleader>t', '<cmd>!zig build test<CR>', { buffer = true, desc = 'Run Zig tests' })
vim.keymap.set('n', '<localleader>b', '<cmd>!zig build<CR>', { buffer = true, desc = 'Build Zig project' })
