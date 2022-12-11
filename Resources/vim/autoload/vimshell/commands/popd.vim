"=============================================================================
" FILE: popd.vim
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
      \ 'name' : 'popd',
      \ 'kind' : 'internal',
      \ 'description' : 'popd [{directory-stack-number}]',
      \}
function! s:command.execute(args, context) abort "{{{
  " Pop directory.

  if empty(b:vimshell.directory_stack)
    " Error.
    call vimshell#error_line(a:context.fd, 'popd: Directory stack is empty.')
    return
  endif

  let arguments = join(a:args)
  if arguments =~ '^\d\+$'
    let pop = str2nr(arguments)
  elseif empty(arguments)
    " Default pop value.
    let pop = 0
  else
    " Error.
    call vimshell#error_line(a:context.fd, 'popd: Arguments error.')
    return
  endif

  if pop >= len(b:vimshell.directory_stack)
    " Overflow.
    call vimshell#error_line(a:context.fd, printf("popd: Not found '%d' in directory stack.", pop))
    return
  endif

  return vimshell#helpers#execute_internal_command('cd',
        \ [ b:vimshell.directory_stack[pop] ], a:context)
endfunction"}}}
function! s:command.complete(args) abort "{{{
  return vimshell#complete#helper#directory_stack(a:args[-1])
endfunction"}}}

function! vimshell#commands#popd#define() abort
  return s:command
endfunction
