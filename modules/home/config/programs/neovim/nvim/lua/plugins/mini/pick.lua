local pick = require('mini.pick')

pick.setup({
  delay = {
    async = 10,
    busy = 50,
  },

  mappings = {
    caret_left = '<Left>',
    caret_right = '<Right>',
    choose = '<CR>',
    choose_in_split = '<C-s>',
    choose_in_tabpage = '<C-t>',
    choose_in_vsplit = '<C-v>',
    choose_marked = '<M-CR>',
    delete_char = '<BS>',
    delete_char_right = '<Del>',
    delete_left = '<C-u>',
    delete_word = '<C-w>',
    mark = '<C-x>',
    mark_all = '<C-a>',
    move_down = '<C-n>',
    move_start = '<C-g>',
    move_up = '<C-p>',
    paste = '<C-r>',
    refine = '<C-Space>',
    refine_marked = '<M-Space>',
    scroll_down = '<C-f>',
    scroll_left = '<C-h>',
    scroll_right = '<C-l>',
    scroll_up = '<C-b>',
    stop = '<Esc>',
    toggle_info = '<S-Tab>',
    toggle_preview = '<Tab>',
  },

  options = {
    content_from_bottom = false,
    use_cache = true,
  },

  source = {
    show = pick.default_show,
  },

  window = {
    config = {
      border = 'single',
      width = math.floor(0.8 * vim.o.columns),
      height = math.floor(0.8 * vim.o.lines),
    },
  },
})
