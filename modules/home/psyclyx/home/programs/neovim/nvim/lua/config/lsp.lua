local servers = {
  nil_ls = {
    cmd = { 'nil' },
    filetypes = { 'nix' },
    root_markers = { 'flake.nix', '.git' },
  },
  lua_ls = {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        diagnostics = { globals = { 'vim' } },
        workspace = {
          library = vim.api.nvim_get_runtime_file('', true),
          checkThirdParty = false,
        },
        telemetry = { enable = false },
      },
    },
  },
  rust_analyzer = {
    cmd = { 'rust-analyzer' },
    filetypes = { 'rust' },
    root_markers = { 'Cargo.toml', '.git' },
    settings = {
      ['rust-analyzer'] = {
        checkOnSave = {
          command = 'clippy',
        },
      },
    },
  },
  clangd = {
    cmd = { 'clangd' },
    filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
    root_markers = { 'compile_commands.json', '.git' },
  },
  ts_ls = {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact', 'typescript.tsx' },
    root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
  },
  clojure_lsp = {
    cmd = { 'clojure-lsp' },
    filetypes = { 'clojure', 'edn' },
    root_markers = { 'project.clj', 'deps.edn', 'build.boot', 'shadow-cljs.edn', '.git' },
  },
  zls = {
    cmd = { 'zls' },
    filetypes = { 'zig', 'zir' },
    root_markers = { 'zls.json', 'build.zig', '.git' },
  },
}

for server, config in pairs(servers) do
  vim.lsp.config(server, config)
  vim.lsp.enable(server)
end

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local opts = { buffer = bufnr, silent = true }

    vim.keymap.set('n', '<leader>cd', vim.lsp.buf.definition,
      vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
    vim.keymap.set('n', '<leader>cD', vim.lsp.buf.type_definition,
      vim.tbl_extend('force', opts, { desc = 'Go to type definition' }))
    vim.keymap.set('n', '<leader>cr', vim.lsp.buf.references, vim.tbl_extend('force', opts, { desc = 'Find references' }))
    vim.keymap.set('n', '<leader>ci', vim.lsp.buf.implementation,
      vim.tbl_extend('force', opts, { desc = 'Go to implementation' }))
    vim.keymap.set('n', '<leader>cn', vim.lsp.buf.rename, vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, vim.tbl_extend('force', opts, { desc = 'Code action' }))
    vim.keymap.set('n', '<leader>cf', vim.lsp.buf.format, vim.tbl_extend('force', opts, { desc = 'Format code' }))
    vim.keymap.set('n', '<leader>ch', vim.lsp.buf.hover, vim.tbl_extend('force', opts, { desc = 'Hover documentation' }))
    vim.keymap.set('n', '<leader>ck', vim.lsp.buf.signature_help,
      vim.tbl_extend('force', opts, { desc = 'Signature help' }))

    vim.keymap.set('n', '<leader>ce', vim.diagnostic.open_float,
      vim.tbl_extend('force', opts, { desc = 'Show diagnostics' }))
    vim.keymap.set('n', '<leader>c[', vim.diagnostic.goto_prev,
      vim.tbl_extend('force', opts, { desc = 'Previous diagnostic' }))
    vim.keymap.set('n', '<leader>c]', vim.diagnostic.goto_next,
      vim.tbl_extend('force', opts, { desc = 'Next diagnostic' }))

    if client and client.supports_method('textDocument/formatting') then
      vim.api.nvim_create_autocmd('BufWritePre', {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr })
        end,
      })
    end
  end,
})

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
