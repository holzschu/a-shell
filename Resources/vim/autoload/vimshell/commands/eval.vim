"=============================================================================
" FILE: eval.vim
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
      \ 'name' : 'eval',
      \ 'kind' : 'internal',
      \ 'description' : 'eval {expression}',
      \}
function! s:command.execute(args, context) abort "{{{
  " Evaluate arguments.

  let line = join(a:args)
  let context = vimshell#init#_context({
        \ 'has_head_spaces' : line =~ '^\s\+',
        \ 'is_interactive' : a:context.is_interactive,
        \ 'is_insert' : a:context.is_insert,
        \})

  try
    call vimshell#parser#eval_script(line, context)
  catch /.*/
    let message = v:exception . ' ' . v:throwpoint
    call vimshell#error_line(context.fd, message)
    return
  endtry
endfunction"}}}

function! vimshell#commands#eval#define() abort
  return s:command
endfunction
