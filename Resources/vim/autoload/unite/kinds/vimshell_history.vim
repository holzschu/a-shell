"=============================================================================
" FILE: vimshell/history.vim
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

let s:save_cpo = &cpo
set cpo&vim

function! unite#kinds#vimshell_history#define() abort "{{{
  return s:kind
endfunction"}}}

let s:kind = {
      \ 'name' : 'vimshell/history',
      \ 'default_action' : 'insert',
      \ 'action_table': {},
      \ 'alias_table' : { 'ex' : 'nop', 'narrow' : 'edit' },
      \ 'parents': ['completion'],
      \}

" Actions "{{{
let s:kind.action_table.delete = {
      \ 'description' : 'delete from vimshell history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ 'is_selectable' : 1,
      \ }
function! s:kind.action_table.delete.func(candidates) abort "{{{
  let current_histories =
        \ a:candidates[0].action__current_histories
  for candidate in a:candidates
    call filter(current_histories,
          \ 'v:val !=# candidate.action__complete_word')
  endfor

  if !a:candidates[0].action__is_external
    call unite#sources#vimshell_history#_change_histories(current_histories)
  endif
endfunction"}}}

let s:kind.action_table.edit = {
      \ 'description' : 'edit history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ }
function! s:kind.action_table.edit.func(candidate) abort "{{{
  let current_histories =
        \ a:candidate.action__current_histories
  let history = input('Please edit history: ',
        \ a:candidate.action__complete_word)
  if history != ''
    let current_histories[
          \ a:candidate.action__source_history_number] = history
  endif

  if !a:candidate.action__is_external
    call unite#sources#vimshell_history#_change_histories(current_histories)
  endif
endfunction"}}}

let s:kind.action_table.execute = {
      \ 'description' : 'execute history',
      \ 'is_selectable' : 1,
      \ }
function! s:kind.action_table.execute.func(candidates) abort "{{{
  let candidate = deepcopy(a:candidates[0])
  let candidate.action__complete_word =
        \ join(map(copy(a:candidates),
        \ 'v:val.action__complete_word'), ' && ')
  call unite#take_action('insert', candidate)

  call vimshell#execute_current_line(unite#get_context().complete)
endfunction"}}}

let s:kind.action_table.insert = {
      \ 'description' : 'insert history',
      \ 'is_selectable' : 1,
      \ }
function! s:kind.action_table.insert.func(candidates) abort "{{{
  if !vimshell#check_prompt()
    call vimshell#echo_error('Not in command line.')
    return
  endif

  let command = join(map(copy(a:candidates),
        \ 'v:val.action__complete_word'), ' && ')

  call setline('.', vimshell#get_prompt() . command)
  if unite#get_context().complete
    startinsert!
  else
    call cursor(0, col('$'))
  endif
endfunction"}}}

let s:kind.action_table.unite__new_candidate = {
      \ 'description' : 'add new history',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ }
function! s:kind.action_table.unite__new_candidate.func(candidate) abort "{{{
  let current_histories =
        \ a:candidate.action__current_histories
  let history = input('Please input new history: ',
        \ '', 'shellcmd')
  if history != ''
    call insert(current_histories, history)
  endif

  if !a:candidate.action__is_external
    call unite#sources#vimshell_history#_change_histories(current_histories)
  endif
endfunction"}}}

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
