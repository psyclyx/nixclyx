vim.cmd('filetype plugin indent on')

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.wildmode = 'list:longest,full'
vim.opt.wildignore = '*.swp,*.o,*.so,*.exe,*.dll'

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.termguicolors = true
vim.cmd('syntax on')
vim.opt.ruler = true
vim.opt.number = true
vim.opt.wrap = false
vim.opt.fillchars = { vert = '│' }
vim.opt.colorcolumn = '80'
vim.opt.cursorline = true
vim.opt.relativenumber = true
vim.opt.hidden = true

vim.opt.listchars = { tab = '→ ', trail = '·' }
vim.opt.list = true

vim.opt.scrolloff = 3

vim.o.icm = 'split'
vim.opt.foldtext = "v:lua.vim.treesitter.foldtext()"

vim.o.showmode = false

vim.o.grepprg = [[rg --glob "!.git" --no-heading --vimgrep --follow $*]]
vim.opt.grepformat = vim.opt.grepformat ^ { "%f:%l:%c:%m" }
