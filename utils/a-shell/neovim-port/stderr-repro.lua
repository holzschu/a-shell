-- Compare legacy sh_main and Dash through the public Neovim process APIs.
vim.o.shell='dash'
vim.o.shellcmdflag='-c'
local results={}
for _, shell in ipairs({'sh','dash'}) do
 local c={shell,'-c','echo x >&2'}
 local s=vim.fn.system(c)
 local item={command=c,system=s,system_status=vim.v.shell_error}
 local out,err={},{}
 local j=vim.fn.jobstart(c,{stdout_buffered=true,stderr_buffered=true,on_stdout=function(_,v) out=v end,on_stderr=function(_,v) err=v end})
 item.job=j
 if j>0 then item.status=vim.fn.jobwait({j},10000)[1];vim.wait(1000,function()return #out>0 and #err>0 end) end
 item.stdout=out;item.stderr=err;results[#results+1]=item
end
vim.fn.writefile({vim.json.encode(results)},'stderr-repro.json')
