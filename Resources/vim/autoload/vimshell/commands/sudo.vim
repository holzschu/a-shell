"=============================================================================
" FILE: sudo.vim
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

function! vimshell#commands#sudo#define() abort
  return s:command
endfunction

let s:command = {
      \ 'name' : 'sudo',
      \ 'kind' : 'external',
      \ 'description' : 'sudo {command}',
      \}

function! s:command.complete(args) abort "{{{
  return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! s:command.execute(args, context) abort "{{{
  " Execute GUI program.
  if empty(a:args)
    call vimshell#error_line(
          \ a:context.fd, 'sudo: Arguments required.')
    return
  endif

  if a:args[0] ==# 'vim' || a:args[0] ==# 'vi'
    " Use sudo.vim.
    let args = a:args[1:]
    if empty(args)
      return
    endif

    let args[0] = 'sudo:' . args[0]
    return vimshell#helpers#execute_internal_command(
          \ 'vim', args, a:context)
  endif

  call vimshell#helpers#execute_internal_command(
        \ 'exe', insert(a:args, 'sudo'), a:context)
endfunction"}}}

" vim: foldmethod=marker
