"=============================================================================
" FILE: repeat.vim
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
      \ 'name' : 'repeat',
      \ 'kind' : 'internal',
      \ 'description' : 'repeat {cnt} {command}',
      \}
function! s:command.execute(args, context) abort "{{{
  " Repeat command.

  if len(a:args) < 2 || a:args[0] !~ '\d\+'
    call vimshell#error_line(a:context.fd, 'repeat: Arguments error.')
    return
  endif

  " Repeat.
  let max = a:args[0]
  let i = 0
  while i < max
    let commands = vimproc#parser#parse_pipe(a:args)
    call vimshell#parser#execute_command(commands, a:context)

    let i += 1
  endwhile
endfunction"}}}

function! vimshell#commands#repeat#define() abort
  return s:command
endfunction
