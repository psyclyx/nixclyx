local starter = require('mini.starter')

-- Minimal start screen config
starter.setup({
  evaluate_single = true,
  items = {},  -- No items = minimal clean screen
  content_hooks = {
    starter.gen_hook.adding_bullet(),
    starter.gen_hook.aligning('center', 'center'),
  },
  footer = '',
  header = '',
  query_updaters = 'abcdefghijklmnopqrstuvwxyz0123456789_-.',
})
