-- Load a pinned local lazy.nvim checkout and an actual local plugin without spawning Git.
local root = vim.fn.getcwd()
local plugin = root .. '/local-plugin'
vim.fn.mkdir(plugin .. '/plugin', 'p')
vim.fn.writefile({ 'vim.g.port_local_plugin_loaded = "LOCAL_PLUGIN_LOADED"' }, plugin .. '/plugin/port.lua')
vim.opt.loadplugins = true
vim.opt.rtp:prepend(root .. '/lazy.nvim')
require('lazy').setup({ { name = 'port-local-plugin', dir = plugin, lazy = false } }, {
  root = root .. '/lazy-plugins',
  lockfile = root .. '/lazy-lock.json',
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  pkg = { enabled = false },
  rocks = { enabled = false },
})
assert(vim.g.port_local_plugin_loaded == 'LOCAL_PLUGIN_LOADED', 'lazy.nvim did not load the local plugin')
assert(jit and not jit.status(), 'LuaJIT must run with JIT disabled')
vim.fn.writefile({ 'LAZY_LOCAL_PLUGIN_LOADED', jit.version, 'JIT_DISABLED' }, 'lazy-smoke.out')
