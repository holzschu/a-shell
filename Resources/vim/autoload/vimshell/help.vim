"=============================================================================
" FILE: help.vim
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

" For echodoc. "{{{
let s:doc_dict = {
      \ 'name' : 'vimshell',
      \ 'rank' : 10,
      \ 'filetypes' : { 'vimshell' : 1 },
      \ }
function! s:doc_dict.search(cur_text) abort "{{{
  " Get command name.
  try
    let args = vimshell#helpers#get_current_args(vimshell#get_cur_text())
  catch /^Exception:/
    return []
  endtry
  if empty(args)
    return []
  endif

  let command = fnamemodify(args[0], ':t:r')

  let commands = vimshell#available_commands(command)
  if has_key(s:cached_doc, command)
    let description = s:cached_doc[command]
  elseif has_key(commands, command)
    let description = commands[command].description
  else
    return []
  endif

  let usage = [{ 'text' : 'Usage: ', 'highlight' : 'Identifier' }]
  if description =~? '^usage:\s*'
    call add(usage, { 'text' : command, 'highlight' : 'Statement' })
    call add(usage, { 'text' : ' ' . join(split(description)[2:]) })
  elseif description =~# command.'\s*'
    call add(usage, { 'text' : command, 'highlight' : 'Statement' })
    call add(usage, { 'text' : description[len(command) :] })
  else
    call add(usage, { 'text' : description })
  endif

  return usage
endfunction"}}}
"}}}

function! vimshell#help#init() abort "{{{
  if exists('g:loaded_echodoc') && g:loaded_echodoc
    call echodoc#register('vimshell', s:doc_dict)
  endif

  call s:load_cached_doc()
endfunction"}}}
function! vimshell#help#get_cached_doc() abort "{{{
  return s:cached_doc
endfunction"}}}
function! vimshell#help#set_cached_doc(cache) abort "{{{
  if vimshell#util#is_sudo()
    return
  endif

  let s:cached_doc = a:cache
  let doc_path = vimshell#get_data_directory() .'/cached-doc'
  call writefile(values(map(deepcopy(s:cached_doc),
        \ 'v:key."!!!".v:val')), doc_path)
endfunction"}}}

function! s:load_cached_doc() abort "{{{
  let s:cached_doc = {}
  if vimshell#util#is_sudo()
    return
  endif

  let doc_path = vimshell#get_data_directory().'/cached-doc'
  if !filereadable(doc_path)
    call writefile([], doc_path)
  endif
  for args in map(readfile(doc_path), 'split(v:val, "!!!")')
    let s:cached_doc[args[0]] = join(args[1:], '!!!')
  endfor
endfunction"}}}

" vim: foldmethod=marker
