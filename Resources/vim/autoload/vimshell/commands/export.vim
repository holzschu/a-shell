"=============================================================================
" FILE: export.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:command = {
      \ 'name' : 'export',
      \ 'kind' : 'internal',
      \ 'description' : 'export {variable-name}={value} ...',
      \}
function! s:command.execute(args, context) abort "{{{
  " Make directory and change the working directory.
  if empty(a:args)
    " Print environment variables.
    let output = vimshell#util#is_windows() ?
          \ system('cmd /c set') :
          \ vimproc#system(printf("%s -c 'env'", &shell))
    call vimshell#print(a:context.fd, output)
    return
  endif

  for arg in a:args
    " Environment variable.
    let varname = matchstr(arg, '^\h\w*\ze=')
    if varname == ''
      call vimshell#error_line(a:context.fd,
            \ 'export: Invalid argument is detected. ' . arg)
      return
    endif

    execute printf('let $%s = %s', varname, string(arg[len(varname)+1:]))
  endfor
endfunction"}}}
function! s:command.complete(args) abort "{{{
  return vimshell#complete#helper#environments(get(a:args, -1, ''))
endfunction"}}}

function! vimshell#commands#export#define() abort
  return s:command
endfunction
