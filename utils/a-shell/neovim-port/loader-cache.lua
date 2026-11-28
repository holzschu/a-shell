-- Run through nvim -l to verify real source loads and persistent bytecode files.
local root = vim.fn.fnamemodify(assert(arg[1], 'pass an owned results directory'), ':p'):gsub('/$', '')
vim.fn.mkdir(root, 'p')
vim.cmd('cd ' .. vim.fn.fnameescape(root))
vim.loader.path = root .. '/cache'
vim.loader.enable()
local deep = root .. ('/' .. ('x'):rep(80)):rep(3)
vim.fn.mkdir(deep .. '/one', 'p')
vim.fn.mkdir(deep .. '/two', 'p')
local first, second = deep .. '/one/module.lua', deep .. '/two/module.lua'
vim.fn.writefile({'return 42'}, first)
vim.fn.writefile({'return 84'}, second)
assert(assert(loadfile(first))() == 42)
local entries = vim.fn.readdir(vim.loader.path)
assert(#entries == 1, 'expected one bytecode cache file')
local cached = vim.loader.path .. '/' .. entries[1]
local before = assert(vim.uv.fs_stat(cached)).mtime
vim.uv.sleep(20)
assert(assert(loadfile(first))() == 42)
local after = assert(vim.uv.fs_stat(cached)).mtime
assert(before.sec == after.sec and before.nsec == after.nsec, 'warm load rewrote the cache')
assert(assert(loadfile(second))() == 84, 'distinct long paths collided')
vim.uv.sleep(20)
vim.fn.writefile({'return 43'}, first)
assert(assert(loadfile(first))() == 43, 'source change did not invalidate cache')
vim.fn.writefile({'return 7'}, 'loader-ordinary.lua')
assert(assert(loadfile('loader-ordinary.lua'))() == 7)
assert(vim.uv.fs_stat(vim.loader.path .. '/loader-ordinary.luac'), 'ordinary cache name changed')
local collision = 'sha256-' .. vim.fn.sha256(first) .. '.lua'
vim.fn.writefile({'return 11'}, collision)
vim.uv.fs_utime(first, 0, 0)
vim.uv.fs_utime(collision, 0, 0)
assert(assert(loadfile(first))() == 43)
assert(assert(loadfile(collision))() == 11, 'hashed and ordinary cache names collided')
assert(assert(loadfile(first))() == 43, 'ordinary load replaced hashed bytecode')
assert(vim.uv.fs_stat(vim.loader.path .. '/=' .. collision .. 'c'), 'reserved cache entry missing')
assert(vim.uv.fs_stat(vim.loader.path .. '/' .. collision .. 'c'), 'ordinary cache entry missing')

local timer_path = deep .. '/timer.lua'
vim.fn.writefile({'return 99'}, timer_path)
local timer = vim.uv.new_timer()
local result
local in_fast_event = false
timer:start(0, 0, function()
  in_fast_event = vim.in_fast_event()
  result = {pcall(function()
    return assert(loadfile(timer_path))(), assert(loadfile(timer_path))()
  end)}
  timer:close()
end)
assert(vim.wait(2000, function() return result ~= nil end), 'timer did not complete')
assert(in_fast_event and result[1], tostring(result[2]))
assert(result[2] == 99 and result[3] == 99, 'fast-event cold/warm load differs')
for _, name in ipairs(vim.fn.readdir(vim.loader.path)) do
  assert(#name <= 143, 'cache filename exceeds the eCryptfs component limit')
end
local invalid = deep .. '/invalid.lua'
vim.fn.writefile({'return )'}, invalid)
assert(loadfile(invalid) == nil, 'invalid Lua source was accepted')
assert(loadfile(deep .. '/missing.lua') == nil, 'missing source was accepted')
vim.fn.writefile({'NVIM_LOADER_CACHE_PASS', 'COLD=42', 'WARM=42', 'DISTINCT=84',
  'INVALIDATED=43', 'FAST_COLD=99', 'FAST_WARM=99', 'BOUNDED_FILENAMES=143'}, root .. '/result.out')
print('NVIM_LOADER_CACHE_PASS')
