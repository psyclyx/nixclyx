local miniclue = require('mini.clue')

miniclue.setup({
  window = {
    delay = 300,
    config = {
      width = 'auto',
    },
  },

  triggers = {
    { mode = 'n', keys = '<Leader>' },
    { mode = 'x', keys = '<Leader>' },
    { mode = 'i', keys = '<C-x>' },
    { mode = 'n', keys = 'g' },
    { mode = 'x', keys = 'g' },
    { mode = 'n', keys = "'" },
    { mode = 'n', keys = '`' },
    { mode = 'x', keys = "'" },
    { mode = 'x', keys = '`' },
    { mode = 'n', keys = '"' },
    { mode = 'x', keys = '"' },
    { mode = 'i', keys = '<C-r>' },
    { mode = 'c', keys = '<C-r>' },
    { mode = 'n', keys = '<C-w>' },
    { mode = 'n', keys = 'z' },
    { mode = 'x', keys = 'z' },
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = ']' },
  },

  clues = {
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.windows({
      submode_move = true,
      submode_navigate = true,
      submode_resize = true,
    }),
    miniclue.gen_clues.z(),

    { mode = 'n', keys = '<Leader>b', desc = '+buffers' },
    { mode = 'n', keys = '<Leader>c', desc = '+code' },
    { mode = 'n', keys = '<Leader>f', desc = '+files' },
    { mode = 'n', keys = '<Leader>g', desc = '+git' },
    { mode = 'n', keys = '<Leader>h', desc = '+help' },
    { mode = 'n', keys = '<Leader>m', desc = '+major-mode' },
    { mode = 'n', keys = '<Leader>p', desc = '+project' },
    { mode = 'n', keys = '<Leader>q', desc = '+quit' },
    { mode = 'n', keys = '<Leader>s', desc = '+search' },
    { mode = 'n', keys = '<Leader>t', desc = '+toggle' },
    { mode = 'n', keys = '<Leader>w', desc = '+windows' },
    { mode = 'n', keys = '<Leader>x', desc = '+text' },
  },
})
