local ai = require('mini.ai')
local extra = require('mini.extra')

ai.setup({
  custom_textobjects = {
    -- Function text objects using treesitter
    f = extra.gen_ai_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),

    -- Block/conditional text objects
    o = extra.gen_ai_spec.treesitter({ a = '@block.outer', i = '@block.inner' }),
    c = extra.gen_ai_spec.treesitter({ a = '@conditional.outer', i = '@conditional.inner' }),

    -- Arguments/parameters (useful for all languages)
    a = extra.gen_ai_spec.treesitter({ a = '@parameter.outer', i = '@parameter.inner' }),

    -- For Clojure s-expressions (built-in brackets work well, but this is explicit)
    -- The default 'b' for brackets already handles (), [], {}

    -- HTML/XML tags are handled by default 't' text object

    -- Lines (builtin enhancement)
    L = extra.gen_ai_spec.line(),

    -- Buffer text object
    g = extra.gen_ai_spec.buffer(),
  },

  n_lines = 500,
  search_method = 'cover_or_next',
})
