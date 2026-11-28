-- Exercise the public editor APIs with real commands, streams and exit statuses.
vim.o.shell = 'dash'
vim.o.shellcmdflag = '-c'
vim.o.shellquote = ''
vim.o.shellxquote = ''
local result = vim.fn.system('echo ok')
assert(vim.v.shell_error == 0, 'system status: ' .. vim.v.shell_error)
assert(result == 'ok\n', 'system output: ' .. vim.inspect(result))
vim.cmd('!ls')
assert(vim.v.shell_error == 0, ':!ls status: ' .. vim.v.shell_error)
local output, errors = {}, {}
local job = vim.fn.jobstart({'ls', '/nvim-worker-missing-fixture'}, {
  stdout_buffered = true, stderr_buffered = true,
  on_stdout = function(_, lines) output = lines end,
  on_stderr = function(_, lines) errors = lines end,
})
assert(job > 0, 'stderr jobstart: ' .. job)
assert(vim.fn.jobwait({job}, 10000)[1] == 1, 'missing path status')
assert(vim.wait(1000, function() return #output > 0 and #errors > 0 end), 'stderr stream EOF')
assert(table.concat(output, '\n') == '', 'unexpected stderr job stdout')
assert(table.concat(errors, '\n'):find('nvim%-worker%-missing%-fixture'), 'missing job stderr: ' .. vim.inspect(errors))
vim.fn.writefile({'NVIM_SUBPROCESS_PASS', vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch}, 'subprocess-result.txt')
