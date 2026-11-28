-- Observe real terminal input through Neovim's public API.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
vim.opt.undofile = false

local function snapshot()
  vim.fn.writefile({vim.api.nvim_get_mode().mode}, root .. '/mode.out')
end

vim.on_key(function(key)
  local bytes = {}
  for i = 1, #key do
    bytes[#bytes + 1] = string.byte(key, i)
  end
  vim.fn.writefile({table.concat(bytes, ',')}, root .. '/keys.out', 'a')
  vim.schedule(snapshot)
end)

vim.api.nvim_create_autocmd('VimEnter', {callback = function()
  snapshot()
  vim.fn.writefile({'READY'}, root .. '/ready.out')
end})

vim.api.nvim_create_user_command('EscapeProbe', function()
  vim.fn.writefile({'WAITING'}, root .. '/getchar-ready.out')
  local key = vim.fn.getcharstr()
  vim.fn.writefile({vim.fn.keytrans(key)}, root .. '/getchar.out')
end, {})

vim.api.nvim_create_user_command('MatrixState', function(args)
  if args.args == 'portrait' then
    vim.fn.writefile({tostring(vim.o.columns), tostring(vim.o.lines)}, root .. '/portrait-state.out')
  else
    local capture = vim.treesitter.get_captures_at_pos(0, 0, 0)[1]
    assert(capture, 'expected a Tree-sitter capture on the Lua keyword')
    vim.fn.writefile({tostring(vim.g.port_init), vim.bo.filetype,
      tostring(vim.o.columns), tostring(vim.o.lines), _VERSION,
      capture.lang .. ':' .. capture.capture}, root .. '/editor-state.out')
  end
  vim.fn.writefile({args.args}, root .. '/state-ready.out')
end, {nargs = 1})
