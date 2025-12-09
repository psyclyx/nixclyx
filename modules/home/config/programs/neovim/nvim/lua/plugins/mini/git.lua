require('mini.git').setup({
  job = {
    git_executable = 'git',
    timeout = 30000,
  },
  command = {
    split = 'auto',
  },
})
