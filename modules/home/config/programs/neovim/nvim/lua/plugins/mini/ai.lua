local ai = require('mini.ai')
local extra = require('mini.extra')

ai.setup({
  -- Custom textobjects beyond the built-in ones
  -- Built-ins include: brackets (), [], {}, <>, quotes "/'/', function calls (f),
  -- arguments (a), tags (t), and user prompt (?)
  custom_textobjects = {
    -- Treesitter-based function textobject (more reliable than pattern-based)
    F = ai.gen_spec.treesitter({
      a = '@function.outer',
      i = '@function.inner',
    }),

    -- Treesitter-based class/type textobject
    C = ai.gen_spec.treesitter({
      a = '@class.outer',
      i = '@class.inner',
    }),

    -- Treesitter-based conditional textobject (if/when/case/match)
    o = ai.gen_spec.treesitter({
      a = '@conditional.outer',
      i = '@conditional.inner',
    }),

    -- Treesitter-based loop textobject
    l = ai.gen_spec.treesitter({
      a = '@loop.outer',
      i = '@loop.inner',
    }),

    -- Number textobject (useful for incrementing/decrementing)
    n = extra.gen_ai_spec.number(),

    -- Entire buffer textobject
    g = extra.gen_ai_spec.buffer(),

    -- Indentation textobject (useful for Python, Nix, YAML, etc.)
    i = extra.gen_ai_spec.indent(),

    -- Line textobject (current line)
    L = extra.gen_ai_spec.line(),

    -- Underscore-separated identifier (snake_case)
    u = ai.gen_spec.pair('_', '_', { type = 'greedy' }),
  },

  -- Mappings for textobject operations
  mappings = {
    around = 'a',
    inside = 'i',

    -- Next/last textobject variants
    around_next = 'an',
    inside_next = 'in',
    around_last = 'al',
    inside_last = 'il',

    -- Jump to left/right edge of textobject
    goto_left = 'g[',
    goto_right = 'g]',
  },

  -- Number of lines within which textobject is searched
  n_lines = 500,

  -- How to search for textobject (when cursor is not inside one)
  -- 'cover_or_next' finds covering match or next occurrence
  search_method = 'cover_or_next',

  -- Whether to disable showing non-error feedback
  silent = false,
})
