"=============================================================================
" FILE: build.vim
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
      \ 'name' : 'build',
      \ 'kind' : 'internal',
      \ 'description' : 'build [{builder-name}, {args}]',
      \}
function! s:command.execute(args, context) abort "{{{
  let args = vimshell#parser#getopt(a:args, {})[0]

  let old_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.')]

  call unite#start([insert(args, 'build')],
        \ { 'no_quit' : 1, 'buffer_name' : 'build'.tabpagenr() })

  let new_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.')]

  noautocmd call vimshell#helpers#restore_pos(old_pos)

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#next_prompt(a:context, 0)
    noautocmd call vimshell#helpers#restore_pos(new_pos)
    stopinsert
  endif
endfunction"}}}

function! s:command.complete(args) abort "{{{
  if len(a:args) == 1
        \ && exists('*unite#sources#build#get_builders_name')
    return vimshell#complete#helper#keyword_simple_filter(
          \ unite#sources#build#get_builders_name(), a:args[-1])
  endif

  return []
endfunction"}}}

function! vimshell#commands#build#define() abort
  return s:command
endfunction
