"=============================================================================
" FILE: h.vim
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
      \ 'name' : 'h',
      \ 'kind' : 'internal',
      \ 'description' : 'h [{pattern}]',
      \}
function! s:command.execute(args, context) abort "{{{
  " Execute from history.

  let histories = vimshell#history#read()
  let hist = ''
  if empty(a:args) || a:args[0] =~ '^-\?\d\+'
    if empty(a:args)
      let num = -1
    else
      let num = str2nr(a:args[0])
    endif

    if num >= len(histories) || -num > len(histories)
      " Error.
      call vimshell#error_line(a:context.fd, 'h: Not found in history.')
      return
    endif

    let hist = histories[num]
  else
    let args = join(a:args)
    for h in histories
      if vimshell#util#head_match(h, args)
        let hist = h
        break
      endif
    endfor

    if hist == ''
      " Error.
      call vimshell#error_line(a:context.fd, 'h: Not found in history.')
      return
    endif
  endif

  if a:context.has_head_spaces
    let hist = ' ' . hist
  endif
  call vimshell#view#_set_prompt_command(hist)

  let context = a:context
  let context.is_interactive = 0
  let context.fd = a:context.fd
  try
    call vimshell#parser#eval_script(hist, context)
  catch
    call vimshell#error_line(context.fd, v:exception)
    call vimshell#error_line(context.fd, v:throwpoint)
  endtry
endfunction"}}}

function! vimshell#commands#h#define() abort
  return s:command
endfunction
