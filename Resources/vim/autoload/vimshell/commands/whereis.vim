"=============================================================================
" FILE: whrereis.vim
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
      \ 'name' : 'whereis',
      \ 'kind' : 'internal',
      \ 'description' : 'whereis command',
      \}
function! s:command.execute(args, context) abort "{{{
  if empty(a:args)
    return
  endif

  for arg in vimproc#get_command_name(a:args[0], $PATH, -1)
    call vimshell#print_line(a:context.fd, arg)
  endfor
endfunction"}}}
function! s:command.complete(args) abort "{{{
  if len(a:args) == 1
    return vimshell#complete#helper#executables(a:args[-1])
  endif

  return []
endfunction"}}}

function! vimshell#commands#whereis#define() abort
  return s:command
endfunction
