"=============================================================================
" FILE: vimshell.vim
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

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:loaded_vimshell')
  runtime! plugin/vimshell.vim
endif

function! vimshell#version() abort "{{{
  return str2nr(printf('%02d%02d', 11, 1))
endfunction"}}}

function! vimshell#echo_error(string) abort "{{{
  echohl Error | echo a:string | echohl None
endfunction"}}}

" Initialize. "{{{
if !exists('g:vimshell_execute_file_list')
  let g:vimshell_execute_file_list = {}
endif
"}}}

" vimshell plugin utility functions. "{{{
function! vimshell#available_commands(...) abort "{{{
  call vimshell#init#_internal_commands(get(a:000, 0, ''))
  return vimshell#variables#internal_commands()
endfunction"}}}
function! vimshell#print(fd, string) abort "{{{
  return vimshell#interactive#print_buffer(a:fd, a:string)
endfunction"}}}
function! vimshell#print_line(fd, string) abort "{{{
  return vimshell#interactive#print_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#error_line(fd, string) abort "{{{
  return vimshell#interactive#error_buffer(a:fd, a:string . "\n")
endfunction"}}}
function! vimshell#print_prompt(...) abort "{{{
  return call('vimshell#view#_print_prompt', a:000)
endfunction"}}}
function! vimshell#print_secondary_prompt() abort "{{{
  return call('vimshell#view#_print_secondary_prompt', a:000)
endfunction"}}}
function! vimshell#start_insert(...) abort "{{{
  return call('vimshell#view#_start_insert', a:000)
endfunction"}}}
function! vimshell#get_prompt(...) abort "{{{
  return call('vimshell#view#_get_prompt', a:000)
endfunction"}}}
function! vimshell#get_secondary_prompt() abort "{{{
  return get(vimshell#get_context(),
        \ 'secondary_prompt', get(g:, 'vimshell_secondary_prompt', '%% '))
endfunction"}}}
function! vimshell#get_user_prompt() abort "{{{
  return get(vimshell#get_context(),
        \ 'user_prompt', get(g:, 'vimshell_user_prompt', ''))
endfunction"}}}
function! vimshell#get_right_prompt() abort "{{{
  return get(vimshell#get_context(),
        \ 'right_prompt', get(g:, 'vimshell_right_prompt', ''))
endfunction"}}}
function! vimshell#get_cur_text() abort "{{{
  return vimshell#interactive#get_cur_text()
endfunction"}}}
function! vimshell#get_cur_line() abort "{{{
  let cur_text = matchstr(getline('.'),
        \ '^.*\%'.col('.').'c' . (mode() ==# 'i' ? '' : '.'))
  return cur_text
endfunction"}}}
function! vimshell#check_prompt(...) abort "{{{
  return call('vimshell#view#_check_prompt', a:000)
endfunction"}}}
function! vimshell#set_execute_file(exts, program) abort "{{{
  return vimshell#util#set_dictionary_helper(g:vimshell_execute_file_list,
        \ a:exts, a:program)
endfunction"}}}
function! vimshell#open(filename) abort "{{{
  call vimproc#open(a:filename)
endfunction"}}}
function! vimshell#cd(directory) abort "{{{
  return vimshell#view#_cd(a:directory)
endfunction"}}}
function! vimshell#execute_current_line(is_insert) abort "{{{
  return &filetype ==# 'vimshell' ?
        \ vimshell#mappings#execute_line(a:is_insert) :
        \ vimshell#int_mappings#execute_line(a:is_insert)
endfunction"}}}
function! vimshell#next_prompt(context, ...) abort "{{{
  return call('vimshell#view#_next_prompt', [a:context] + a:000)
endfunction"}}}
function! vimshell#is_interactive() abort "{{{
  let is_valid = get(get(b:interactive, 'process', {}), 'is_valid', 0)
  return b:interactive.type ==# 'interactive'
        \ || (b:interactive.type ==# 'vimshell' && is_valid)
endfunction"}}}
function! vimshell#get_data_directory() abort "{{{
  let data_directory = vimshell#util#set_default(
        \ 'g:vimshell_data_directory',
        \  (exists('$XDG_DATA_HOME') ?
        \   $XDG_DATA_HOME . '/vimshell' : '~/.local/share/vimshell'),
        \ 'g:vimshell_temporary_directory')
  let data_directory = vimshell#util#substitute_path_separator(
        \ expand(data_directory))
  if !isdirectory(data_directory) && !vimshell#util#is_sudo()
    call mkdir(data_directory, 'p')
  endif

  return data_directory
endfunction"}}}
"}}}

" User helper functions.
function! vimshell#execute(cmdline, ...) abort "{{{
  return call('vimshell#helpers#execute', [a:cmdline] + a:000)
endfunction"}}}
function! vimshell#execute_async(cmdline, ...) abort "{{{
  return call('vimshell#helpers#execute_async', [a:cmdline] + a:000)
endfunction"}}}
function! vimshell#set_context(context) abort "{{{
  let context = vimshell#init#_context(a:context)
  let s:context = context
  if exists('b:vimshell')
    if has_key(b:vimshell, 'context')
      call extend(b:vimshell.context, a:context)
    else
      let b:vimshell.context = context
    endif
  endif
endfunction"}}}
function! vimshell#get_context() abort "{{{
  if exists('b:vimshell')
    return extend(copy(b:vimshell.context),
          \ get(b:vimshell.continuation, 'context', {}))
  elseif !exists('s:context')
    " Set context.
    let context = {
      \ 'has_head_spaces' : 0,
      \ 'is_interactive' : 0,
      \ 'is_insert' : 0,
      \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
      \}

    call vimshell#set_context(context)
  endif

  return s:context
endfunction"}}}
function! vimshell#set_alias(name, value) abort "{{{
  return vimshell#helpers#set_alias(a:name, a:value)
endfunction"}}}
function! vimshell#set_galias(name, value) abort "{{{
  return vimshell#helpers#set_galias(a:name, a:value)
endfunction"}}}
function! vimshell#set_syntax(syntax_name) abort "{{{
  let b:interactive.syntax = a:syntax_name
endfunction"}}}
function! vimshell#get_status_string() abort "{{{
  return !exists('b:vimshell') ? '' : (
        \ (!empty(b:vimshell.continuation) ? '[async] ' : '') .
        \ b:vimshell.current_dir)
endfunction"}}}

function! vimshell#complete(arglead, cmdline, cursorpos) abort "{{{
  return vimshell#helpers#complete(a:arglead, a:cmdline, a:cursorpos)
endfunction"}}}
function! vimshell#get_prompt_length(...) abort "{{{
  return len(matchstr(get(a:000, 0, getline('.')),
        \ vimshell#get_context().prompt_pattern))
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
