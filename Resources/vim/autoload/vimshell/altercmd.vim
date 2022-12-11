"=============================================================================
" FILE: altercmd.vim
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

function! vimshell#altercmd#define(original, alternative) abort "{{{
  execute 'inoreabbrev <buffer><expr>' a:original
        \ '(join(vimshell#helpers#get_current_args()) ==# "' . a:original  . '") &&'
        \ 'empty(b:vimshell.continuation) ?'
        \ s:SID_PREFIX().'recursive_expand_altercmd('.string(a:original).')' ':' string(a:original)
  let b:vimshell.altercmd_table[a:original] = a:alternative
endfunction"}}}

function! s:SID_PREFIX() abort
  return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSID_PREFIX$')
endfunction

function! s:recursive_expand_altercmd(string) abort
  " Recursive expand altercmd.
  let abbrev = b:vimshell.altercmd_table[a:string]
  let expanded = {}
  while 1
    if has_key(expanded, abbrev) ||
          \ !has_key(b:vimshell.altercmd_table, abbrev)
      break
    endif

    let expanded[abbrev] = 1
    let abbrev = b:vimshell.altercmd_table[abbrev]
  endwhile

  return abbrev
endfunction

" vim: foldmethod=marker
