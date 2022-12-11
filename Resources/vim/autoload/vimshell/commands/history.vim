"=============================================================================
" FILE: history.vim
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
      \ 'name' : 'history',
      \ 'kind' : 'internal',
      \ 'description' : 'history [{search-string}]',
      \}
function! s:command.execute(args, context) abort "{{{
  let histories = vimshell#history#read()

  let arguments = join(a:args, ' ')
  if arguments =~ '^-\?\d\+$'
    let search = ''
    let max = str2nr(arguments)
  elseif empty(arguments)
    " Default max value.
    let search = ''
    let max = 20
  else
    let search = arguments
    let max = len(histories)
  endif

  if max < 0
    let max = -max
  endif

  if max == 0 || max >= len(histories)
    " Overflow.
    let max = 0
  endif

  let list = []
  let cnt = 0
  for hist in histories
    if search == '' || vimshell#util#head_match(hist, search)
      call add(list, [cnt, hist])
    endif

    let cnt += 1
  endfor

  for [cnt, hist] in list[-max :]
    call vimshell#print_line(a:context.fd, printf('%3d: %s', cnt, hist))
  endfor
endfunction"}}}

function! vimshell#commands#history#define() abort
  return s:command
endfunction
