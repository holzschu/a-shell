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

function! vimshell#history#append(command) abort "{{{
  " Reduce blanks.
  let command = substitute(a:command, '\s\+', ' ', 'g')

  " Reload history.
  if &filetype ==# 'vimshell'
    if !empty(b:vimshell.continuation) && !vimshell#check_prompt()
      " Search program name.
      let statement = b:vimshell.continuation.statements[0].statement
      let program = fnamemodify(vimshell#parser#parse_program(
            \ statement), ':t:r')
      let no_history_commands = g:vimshell_interactive_no_save_history_commands
    else
      let program = matchstr(command, vimshell#helpers#get_program_pattern())
      let no_history_commands = g:vimshell_no_save_history_commands
    endif
  else
    " Remove "int-" in filetype.
    let program = substitute(&filetype, '^int-', '', 'g')
    let no_history_commands = g:vimshell_interactive_no_save_history_commands
  endif

  if program == '' || program =~ '^\\\?!'
        \ || has_key(no_history_commands, program)
        \ || isdirectory(program)
    " No history command.
    return
  endif

  " Reload history.
  let histories = vimshell#history#read()

  " Filtering.
  let histories = add(filter(histories, "v:val !=# command"), command)

  if g:vimshell_max_command_history > 0 &&
        \ len(histories) > g:vimshell_max_command_history
    " Truncate.
    let histories = histories[-g:vimshell_max_command_history :]
  endif

  call vimshell#history#write(histories)
endfunction"}}}
function! vimshell#history#read(...) abort "{{{
  if vimshell#util#is_sudo()
    return []
  endif

  let history_path = get(a:000, 0, vimshell#history#get_history_path())
  return filereadable(history_path) ?
        \ readfile(history_path) : []
endfunction"}}}
function! vimshell#history#write(list, ...) abort "{{{
  if vimshell#util#is_sudo()
    return []
  endif

  let history_path = get(a:000, 0, vimshell#history#get_history_path())

  " Save history file.
  call writefile(a:list, history_path)
endfunction"}}}

function! vimshell#history#get_history_path() abort "{{{
  if &filetype ==# 'vimshell' &&
        \ (empty(b:vimshell.continuation) || !vimshell#check_prompt())
    let history_path = vimshell#get_data_directory() . '/command-history'
    if !filereadable(history_path)
      " Create file.
      call writefile([], history_path)
    endif
  else
    let history_dir = vimshell#get_data_directory() . '/int-history'
    if !isdirectory(fnamemodify(history_dir, ':p'))
      call mkdir(fnamemodify(history_dir, ':p'), 'p')
    endif

    if &filetype ==# 'vimshell'
      " Search program name.
      let program = vimshell#parser#parse_program(
            \ b:vimshell.continuation.statements[0].statement)

      let program = 'int-' . fnamemodify(program, ':t:r')
    else
      let program = &filetype
    endif

    if &filetype == ''
      let program = 'unknown'
    endif

    let history_path = history_dir.'/'.program
  endif

  return history_path
endfunction"}}}

" vim: foldmethod=marker
