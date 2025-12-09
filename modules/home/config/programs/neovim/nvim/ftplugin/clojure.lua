vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2
vim.opt_local.expandtab = true

vim.keymap.set('n', '<localleader>ee', '<cmd>ConjureEval<CR>', { buffer = true, desc = 'Evaluate form' })
vim.keymap.set('n', '<localleader>er', '<cmd>ConjureEvalRoot<CR>', { buffer = true, desc = 'Evaluate root form' })
vim.keymap.set('n', '<localleader>ew', '<cmd>ConjureEvalWord<CR>', { buffer = true, desc = 'Evaluate word' })
vim.keymap.set('n', '<localleader>eb', '<cmd>ConjureEvalBuf<CR>', { buffer = true, desc = 'Evaluate buffer' })
vim.keymap.set('v', '<localleader>ee', '<cmd>ConjureEval<CR>', { buffer = true, desc = 'Evaluate selection' })

vim.keymap.set('n', '<localleader>ll', '<cmd>ConjureLogToggle<CR>', { buffer = true, desc = 'Toggle log' })
vim.keymap.set('n', '<localleader>ls', '<cmd>ConjureLogSplit<CR>', { buffer = true, desc = 'Split log' })
vim.keymap.set('n', '<localleader>lv', '<cmd>ConjureLogVSplit<CR>', { buffer = true, desc = 'VSplit log' })

vim.keymap.set('n', '<localleader>cn', '<cmd>ConjureCljConnect<CR>', { buffer = true, desc = 'Connect to nREPL' })
