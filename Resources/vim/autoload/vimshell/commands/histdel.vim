"=============================================================================
" FILE: histdel.vim
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
      \ 'name' : 'histdel',
      \ 'kind' : 'internal',
      \ 'description' : 'histdel {history-number}',
      \}
function! s:command.execute(args, context) abort "{{{
  " Delete from history.

  if empty(a:args)
    call vimshell#error_line(a:context.fd, 'histdel: Arguments required.')
    return
  endif

  let histories = vimshell#history#read()
  let del_hist = {}
  for d in a:args
    if d >= len(histories) || -d > len(histories)
      " Error.
      call vimshell#error_line(a:context.fd, 'histdel: Not found in history.')
      return
    elseif d < 0
      let d = len(histories) + d
    endif

    let del_hist[d] = 1
  endfor

  let new_hist = []
  let cnt = 0
  for h in histories
    if !has_key(del_hist, cnt)
      call add(new_hist, h)
    endif
    let cnt += 1
  endfor

  call vimshell#history#write(new_hist)
endfunction"}}}

function! vimshell#commands#histdel#define() abort
  return s:command
endfunction
