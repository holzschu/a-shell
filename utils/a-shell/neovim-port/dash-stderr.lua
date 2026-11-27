-- Independent diagnostic for the current ios_system Dash stderr limitation.
local system_output = vim.fn.system({'dash', '-c', 'echo x >&2'})
local system_status = vim.v.shell_error
local output, errors = {}, {}
local job = vim.fn.jobstart({'dash', '-c', 'echo job-ok; echo job-err >&2; exit 7'}, {
  stdout_buffered = true, stderr_buffered = true,
  on_stdout = function(_, lines) output = lines end,
  on_stderr = function(_, lines) errors = lines end,
})
assert(job > 0, 'jobstart: ' .. job)
local status = vim.fn.jobwait({job}, 10000)[1]
assert(vim.wait(1000, function() return #output > 0 and #errors > 0 end), 'job stream EOF')
local stdout = table.concat(output, '\n')
local stderr = table.concat(errors, '\n')
local actual = vim.inspect({system_status = system_status, system_output = system_output,
                            status = status, stdout = stdout, stderr = stderr})
assert(system_status == 0 and system_output == 'x\n' and status == 7 and
       stdout == 'job-ok\n' and stderr == 'job-err\n', actual)
