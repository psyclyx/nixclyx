local files = require('mini.files')

files.setup({
  content = {
    filter = nil, -- Show all files by default
    prefix = nil, -- Use default prefix
    sort = nil,   -- Use default sorting
  },

  mappings = {
    close = 'q',
    go_in = 'l',
    go_in_plus = '<CR>',
    go_out = 'h',
    go_out_plus = 'H',
    reset = '<BS>',
    reveal_cwd = '@',
    show_help = 'g?',
    synchronize = '=',
    trim_left = '<',
    trim_right = '>',
  },

  options = {
    permanent_delete = true,
    use_as_default_explorer = true,
  },

  windows = {
    max_number = math.huge,
    preview = true,
    width_focus = 30,
    width_nofocus = 15,
    width_preview = 50,
  },
})

-- Add custom keybindings when mini.files is open
vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesBufferCreate',
  callback = function(args)
    local buf_id = args.data.buf_id

    -- Split horizontally
    vim.keymap.set('n', '<C-s>', function()
      local entry = files.get_fs_entry()
      if entry and entry.fs_type == 'file' then
        files.close()
        vim.cmd('split ' .. vim.fn.fnameescape(entry.path))
      end
    end, { buffer = buf_id, desc = 'Open in horizontal split' })

    -- Split vertically
    vim.keymap.set('n', '<C-v>', function()
      local entry = files.get_fs_entry()
      if entry and entry.fs_type == 'file' then
        files.close()
        vim.cmd('vsplit ' .. vim.fn.fnameescape(entry.path))
      end
    end, { buffer = buf_id, desc = 'Open in vertical split' })

    -- Open in tab
    vim.keymap.set('n', '<C-t>', function()
      local entry = files.get_fs_entry()
      if entry and entry.fs_type == 'file' then
        files.close()
        vim.cmd('tabnew ' .. vim.fn.fnameescape(entry.path))
      end
    end, { buffer = buf_id, desc = 'Open in new tab' })
  end,
})
