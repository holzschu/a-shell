"=============================================================================
" FILE: mkcd.vim
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
      \ 'name' : 'mkcd',
      \ 'kind' : 'internal',
      \ 'description' : 'mkcd {directory-name}',
      \}
function! s:command.execute(args, context) abort "{{{
  " Make directory and change the working directory.

  if empty(a:args)
    " Move to HOME directory.
    let arguments = $HOME
  elseif len(a:args) == 2
    " Substitute current directory.
    let arguments = substitute(getcwd(), a:args[0], a:args[1], 'g')
  elseif len(a:args) > 2
    call vimshell#error_line(a:context.fd, 'mkcd: Too many arguments.')
    return
  else
    " Filename escape.
    let arguments = substitute(a:args[0], '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), '')
  endif

  if !isdirectory(arguments) && !filereadable(arguments)
    " Make directory.
    call mkdir(arguments)
  endif

  return vimshell#helpers#execute_internal_command('cd', a:args, a:context)
endfunction"}}}

function! vimshell#commands#mkcd#define() abort
  return s:command
endfunction
