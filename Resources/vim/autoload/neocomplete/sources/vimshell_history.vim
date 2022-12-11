"=============================================================================
" FILE: vimshell_history.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
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

function! neocomplete#sources#vimshell_history#define() abort "{{{
  return s:source
endfunction "}}}

let s:source = {
      \ 'name' : 'vimshell/history',
      \ 'kind' : 'manual',
      \ 'hooks' : {},
      \ 'max_candidates' : 100,
      \ 'matchers' : [],
      \ 'sorters' : [],
      \ 'mark' : '[history]',
      \ }

function! s:source.hooks.on_post_filter(context) abort "{{{
  for candidate in a:context.candidates
    let candidate.abbr =
          \ substitute(candidate.word, '\s\+$', '>-', '')
  endfor
endfunction"}}}

function! s:source.get_complete_position(context) abort "{{{
  if neocomplete#is_auto_complete() || !vimshell#check_prompt()
    return -1
  endif

  return vimshell#get_prompt_length()
endfunction "}}}

function! s:source.gather_candidates(context) abort "{{{
  return filter(reverse(vimshell#history#read()),
        \ 'stridx(v:val, a:context.complete_str) >= 0')
endfunction "}}}

" ies foldmethod=marker
