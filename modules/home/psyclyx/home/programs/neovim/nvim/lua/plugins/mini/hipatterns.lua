local hipatterns = require('mini.hipatterns')

hipatterns.setup({
  highlighters = {
    -- Highlight standalone keywords
    fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
    hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
    todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
    note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
    warning = { pattern = '%f[%w]()WARNING()%f[%W]', group = 'MiniHipatternsNote' },
    bug = { pattern = '%f[%w]()BUG()%f[%W]', group = 'MiniHipatternsFixme' },
    xxx = { pattern = '%f[%w]()XXX()%f[%W]', group = 'MiniHipatternsHack' },

    -- Highlight hex color strings like #ff0000
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})
