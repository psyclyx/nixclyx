local completion = require('mini.completion')

completion.setup({
  lsp_completion = {
    source_func = 'omnifunc',
    auto_setup = true,
  },
  delay = {
    completion = 50,
    signature = 50,
  },
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local bufnr = args.buf
    vim.bo[bufnr].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
  end
})
