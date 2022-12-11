"=============================================================================
" FILE: let.vim
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
      \ 'name' : 'let',
      \ 'kind' : 'special',
      \ 'description' : 'let ${var-name} = {expression}',
      \}
function! s:command.execute(args, context) abort "{{{
    let args = join(a:args)

    if args !~ '^$$\?\h\w*'
        call vimshell#error_line(a:context.fd, 'let: Wrong syntax.')
        return
    endif

    if args =~ '^$\zs\l\w*'
        " User variable.
        let varname = printf("b:vimshell.variables['%s']", matchstr(args, '^$\zs\l\w*'))
    elseif args =~ '^$\u\w*'
        " Environment variable.
        let varname = matchstr(args, '^$\u\w*')
    elseif args =~ '^$$\h\w*'
        " System variable.
        let varname = printf("b:vimshell.system_variables['%s']", matchstr(args, '^$$\zs\h\w*'))
    else
        let varname = ''
    endif

    let expression = args[match(args, '^$$\?\h\w*\zs') :]
    while expression =~ '$$\h\w*'
        let expression = substitute(expression, '$$\h\w*', printf("b:vimshell.system_variables['%s']", matchstr(expression, '$$\zs\h\w*')), '')
    endwhile
    while expression =~ '$\l\w*'
        let expression = substitute(expression, '$\l\w*', printf("b:vimshell.variables['%s']", matchstr(expression, '$\zs\l\w*')), '')
    endwhile

    execute 'let ' . varname . expression
endfunction"}}}

function! vimshell#commands#let#define() abort
  return s:command
endfunction
