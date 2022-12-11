"=============================================================================
" FILE: mappings.vim
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

" Define default mappings.
function! vimshell#mappings#define_default_mappings() abort "{{{
  " Plugin keymappings "{{{
  nnoremap <buffer><silent> <Plug>(vimshell_enter)
        \ :<C-u>call vimshell#execute_current_line(0)<CR><ESC>
  nnoremap <buffer><silent> <Plug>(vimshell_previous_prompt)
        \ :<C-u>call <SID>previous_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_next_prompt)
        \ :<C-u>call <SID>next_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_delete_previous_output)
        \ :<C-u>call <SID>delete_previous_output()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_paste_prompt)
        \ :<C-u>call vimshell#mappings#_paste_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_move_end_argument)
        \ :<C-u>call <SID>move_end_argument()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_hide)
        \ :<C-u>call <SID>hide()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_exit)
        \ :<C-u>call <SID>exit()<CR>
  nnoremap <buffer><expr> <Plug>(vimshell_change_line)
        \ vimshell#check_prompt() ?
        \ printf('0%dlc$', vimshell#util#strchars(
        \ matchstr(getline('.'), b:vimshell.context.prompt_pattern))) : 'ddO'
  nmap  <buffer> <Plug>(vimshell_delete_line)
        \ <Plug>(vimshell_change_line)<ESC>
  nnoremap <buffer><silent> <Plug>(vimshell_hangup)
        \ :<C-u>call <SID>hangup(0)<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interrupt)
        \ :<C-u>call <SID>interrupt(0)<CR>
  inoremap <buffer><silent> <Plug>(vimshell_send_eof)
        \ <C-v><C-d><C-o>:call vimshell#execute_current_line(1)<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_insert_enter)
        \ :<C-u>call <SID>insert_enter()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_insert_head)
        \ :<C-u>call <SID>insert_head()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_append_enter)
        \ :<C-u>call <SID>append_enter()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_append_end)
        \ :<C-u>call <SID>append_end()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_clear)
        \ :<C-u>call <SID>clear(0)<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_move_head)
        \ :<C-u>call <SID>move_head()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_execute_by_background)
        \ :<C-u>call <SID>execute_by_background(0)<CR>

  inoremap <buffer><silent><expr> <Plug>(vimshell_command_complete)
        \ pumvisible() ?
        \   "\<C-n>" :
        \ !empty(b:vimshell.continuation) ?
        \   "\<C-o>:call vimshell#int_mappings#command_complete()\<CR>" :
        \ vimshell#parser#check_wildcard() ?
        \   <SID>expand_wildcard() : vimshell#complete#start()
  inoremap <buffer><silent><expr> <Plug>(vimshell_zsh_complete)
        \ unite#sources#vimshell_zsh_complete#start_complete(!0)
  inoremap <buffer><silent> <Plug>(vimshell_push_current_line)
        \ <ESC>:call <SID>push_current_line()<CR>
  inoremap <buffer><silent> <Plug>(vimshell_insert_last_word)
        \ <ESC>:call <SID>insert_last_word()<CR>
  inoremap <buffer><silent> <Plug>(vimshell_move_head)
        \ <ESC>:call <SID>insert_head()<CR>
  inoremap <buffer><silent><expr> <Plug>(vimshell_delete_backward_line)
        \ <SID>delete_backward_line()
  inoremap <buffer><silent><expr> <Plug>(vimshell_delete_backward_word)
        \ vimshell#get_cur_text()  == '' ? '' : "\<C-w>"
  inoremap <buffer><silent> <Plug>(vimshell_enter)
        \ <C-g>u<C-o>:call vimshell#execute_current_line(1)<CR>
  inoremap <buffer><silent> <Plug>(vimshell_interrupt)
        \ <C-o>:call <SID>interrupt(1)<CR>
  inoremap <buffer><silent> <Plug>(vimshell_move_previous_window)
        \ <ESC><C-w>p

  inoremap <buffer><silent><expr> <Plug>(vimshell_delete_backward_char)
        \ <SID>delete_backward_char()
  inoremap <buffer><silent><expr> <Plug>(vimshell_another_delete_backward_char)
        \ <SID>delete_another_backward_char()
  inoremap <buffer><silent><expr> <Plug>(vimshell_delete_forward_line)
        \ col('.') == col('$') ? "" : "\<ESC>lDa"
  inoremap <buffer><silent> <Plug>(vimshell_clear)
        \ <ESC>:call <SID>clear(1)<CR>
  inoremap <buffer><silent> <Plug>(vimshell_execute_by_background)
        \ <ESC>:call <SID>execute_by_background(1)<CR>
  inoremap <buffer><silent> <Plug>(vimshell_exit)
        \ <ESC>:call <SID>exit()<CR>
  inoremap <buffer><silent> <Plug>(vimshell_hide)
        \ <ESC>:call <SID>hide()<CR>
  inoremap <expr><buffer><silent> <Plug>(vimshell_history_unite)
        \ unite#sources#vimshell_history#start_complete(!0)
  inoremap <expr><buffer><silent> <Plug>(vimshell_history_complete)
        \ <SID>start_history_complete()
  "}}}

  if get(g:, 'vimshell_no_default_keymappings', 0)
    return
  endif

  " Normal mode key-mappings.
  " Execute command.
  nmap <buffer> <CR> <Plug>(vimshell_enter)
  " Hide vimshell.
  nmap <buffer> q <Plug>(vimshell_hide)
  " Exit vimshell.
  nmap <buffer> Q <Plug>(vimshell_exit)
  " Move to previous prompt.
  nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
  " Move to next prompt.
  nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)
  " Paste this prompt.
  nmap <buffer> <C-y> <Plug>(vimshell_paste_prompt)
  " Search end argument.
  nmap <buffer> E <Plug>(vimshell_move_end_argument)
  " Change line.
  nmap <buffer> cc <Plug>(vimshell_change_line)
  " Delete line.
  nmap <buffer> dd <Plug>(vimshell_delete_line)
  " Start insert.
  nmap <buffer> I         <Plug>(vimshell_insert_head)
  nmap <buffer> A         <Plug>(vimshell_append_end)
  nmap <buffer> i         <Plug>(vimshell_insert_enter)
  nmap <buffer> a         <Plug>(vimshell_append_enter)
  nmap <buffer> ^         <Plug>(vimshell_move_head)
  " Interrupt.
  nmap <buffer> <C-c> <Plug>(vimshell_interrupt)
  nmap <buffer> <C-k> <Plug>(vimshell_hangup)
  " Clear.
  nmap <buffer> <C-l> <Plug>(vimshell_clear)
  " Execute background.
  nmap <buffer> <C-z> <Plug>(vimshell_execute_by_background)

  " Insert mode key-mappings.
  " Execute command.
  inoremap <expr> <SID>(bs-ctrl-])
        \ getline('.')[col('.') - 2] ==# "\<C-]>" ? "\<BS>" : ''
  imap <buffer> <C-]>               <C-]><SID>(bs-ctrl-])
  imap <buffer> <CR>                <C-]><Plug>(vimshell_enter)

  " History completion.
  imap <buffer> <C-l> <Plug>(vimshell_history_unite)
  inoremap <buffer><silent><expr> <C-p> pumvisible() ? "\<C-p>" :
        \ <SID>start_history_complete()
  inoremap <buffer><silent><expr> <C-n> pumvisible() ? "\<C-n>" :
        \ <SID>start_history_complete()
  inoremap <buffer><silent><expr> <Up> pumvisible() ? "\<C-p>" :
        \ <SID>start_history_complete()
  inoremap <buffer><silent><expr> <Down> pumvisible() ? "\<C-n>" :
        \ <SID>start_history_complete()

  " Command completion.
  imap <buffer> <TAB>  <Plug>(vimshell_command_complete)
  " Move to Beginning of command.
  imap <buffer> <C-a> <Plug>(vimshell_move_head)
  " Delete all entered characters in the current line.
  imap <buffer> <C-u> <Plug>(vimshell_delete_backward_line)
  " Delete previous word characters in the current line.
  imap <buffer> <C-w> <Plug>(vimshell_delete_backward_word)
  " Push current line to stack.
  imap <silent><buffer><expr> <C-z> vimshell#mappings#smart_map(
        \ "\<Plug>(vimshell_push_current_line)",
        \ "\<Plug>(vimshell_execute_by_background)")
  " Insert last word.
  imap <buffer> <C-t> <Plug>(vimshell_insert_last_word)
  " Interrupt.
  imap <buffer> <C-c> <Plug>(vimshell_interrupt)
  imap <buffer> <C-d> <Plug>(vimshell_send_eof)
  " Delete char.
  imap <buffer> <C-h>    <Plug>(vimshell_delete_backward_char)
  imap <buffer> <BS>     <Plug>(vimshell_delete_backward_char)
  " Delete line.
  imap <buffer> <C-k>     <Plug>(vimshell_delete_forward_line)
endfunction"}}}
function! vimshell#mappings#smart_map(vimshell_map, execute_map) abort
  return empty(b:vimshell.continuation) ? a:vimshell_map : a:execute_map
endfunction

" VimShell key-mappings functions.
function! s:push_current_line() abort "{{{
  " Check current line.
  if !vimshell#check_prompt()
    return
  endif

  call add(b:vimshell.commandline_stack, getline('.'))

  " Todo:
  " Print command line stack.
  " let stack = map(deepcopy(b:vimshell.commandline_stack),
  "       \ 'vimshell#view#_get_prompt_command(v:val)')
  " call append('.', stack)

  " Set prompt line.
  call setline('.', vimshell#get_prompt())

  call vimshell#view#_simple_insert()
endfunction"}}}
function! s:push_and_execute(command) abort "{{{
  " Check current line.
  if !vimshell#check_prompt()
    return
  endif

  call add(b:vimshell.commandline_stack, getline('.'))

  " Set prompt line.
  call setline('.', vimshell#get_prompt() . a:command)

  call vimshell#mappings#execute_line(1)
endfunction"}}}

function! vimshell#mappings#execute_line(is_insert) abort "{{{
  let oldpos = getpos('.')
  let b:interactive.output_pos = getpos('.')

  if !empty(b:vimshell.continuation)
    if line('.') != line('$')
      " History execution.
      call vimshell#int_mappings#_paste_prompt()
    endif

    call vimshell#util#disable_auto_complete()

    call vimshell#interactive#execute_pty_inout(a:is_insert)

    try
      call vimshell#parser#execute_continuation(a:is_insert)
    catch
      " Error.
      let context = b:vimshell.continuation.context
      if v:exception !~# '^Vim\%((\a\+)\)\?:Interrupt'
        call vimshell#error_line(
              \ context.fd, v:exception . ' ' . v:throwpoint)
      endif
      let b:vimshell.continuation = {}
      call vimshell#print_prompt(context)
      call vimshell#start_insert(a:is_insert)
    endtry
  else
    if vimshell#check_prompt() && line('.') != line('$')
      " History execution.
      call vimshell#mappings#_paste_prompt()
    endif

    if line('.') == line('$')
      call s:execute_command_line(a:is_insert, oldpos)
    endif
  endif
endfunction"}}}
function! s:execute_command_line(is_insert, oldpos) abort "{{{
  " Get command line.
  let line = vimshell#view#_get_prompt_command()
  let context = {
        \ 'has_head_spaces' : line =~ '^\s\+',
        \ 'is_interactive' : 1,
        \ 'is_insert' : a:is_insert,
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''},
        \}

  if line =~ '^\s*-\s*$'
    " Popd.
    call vimshell#helpers#execute_internal_command('cd', ['-'], {})
  elseif line =~ '^\s*$'
    " Call emptycmd filter.
    let line = vimshell#hook#call_filter('emptycmd', context, line)
  endif

  if line =~ '^\s*$\|^\s*-\s*$'
    call vimshell#print_prompt(context)

    call vimshell#start_insert(a:is_insert)
    return
  endif

  " Move to line end.
  call cursor(0, col('$'))

  try
    call vimshell#parser#check_script(line)
  catch /^Exception: Quote\|^Exception: Join to next line/
    call vimshell#print_secondary_prompt()

    call vimshell#start_insert(a:is_insert)
    return
  endtry

  if g:vimshell_enable_transient_user_prompt
        \ && vimshell#view#_check_user_prompt()
    " Delete previous user prompt.
    silent execute vimshell#view#_check_user_prompt().',-1 delete _'
  endif

  " Call preparse filter.
  let line = vimshell#hook#call_filter('preparse', context, line)

  " Save cmdline.
  let b:vimshell.cmdline = line

  try
    " Not append history if starts spaces or dups.
    if line !~ '^\s'
      call vimshell#history#append(line)
    endif

    let ret = vimshell#parser#eval_script(line, context)
  catch /File ".*" is not found./
    " Command not found.
    let oldline = line
    let line = vimshell#hook#call_filter('notfound', context, line)
    if line != '' && line !=# oldline
      " Retry.
      call setpos('.', a:oldpos)
      call vimshell#view#_set_prompt_command(line)
      return s:execute_command_line(a:is_insert, a:oldpos)
    endif

    " Error.
    call vimshell#error_line(
          \ context.fd, 'command not found: ' . matchstr(v:exception,
          \ 'File "\zs.*\ze" is not found.'))
    call vimshell#next_prompt(context, a:is_insert)
    call vimshell#start_insert(a:is_insert)
    return
  catch
    " Error.
    call vimshell#error_line(
          \ context.fd, v:exception . ' ' . v:throwpoint)
    call vimshell#next_prompt(context, a:is_insert)
    call vimshell#start_insert(a:is_insert)
    return
  endtry

  if ret == 0
    call vimshell#next_prompt(context, a:is_insert)
  endif

  call vimshell#start_insert(a:is_insert)
endfunction"}}}
function! s:previous_prompt() abort "{{{
  if empty(b:vimshell.continuation)
    call s:search_prompt('bWn')
  else
    let prompts = sort(filter(map(keys(b:interactive.prompt_history),
          \ 'str2nr(v:val)'), 'v:val < line(".")'))
    if !empty(prompts)
      call cursor(prompts[-1], len(vimshell#interactive#get_prompt()) + 1)
    endif
  endif
endfunction"}}}
function! s:next_prompt() abort "{{{
  if empty(b:vimshell.continuation)
    call s:search_prompt('Wn')
  else
    let prompts = sort(filter(map(keys(b:interactive.prompt_history),
          \ 'str2nr(v:val)'), 'v:val > line(".")'))
    if !empty(prompts)
      call cursor(prompts[0], len(vimshell#interactive#get_prompt()) + 1)
    endif
  endif
endfunction"}}}
function! s:search_prompt(flag) abort "{{{
  let col = col('.')
  call cursor(0, 1)
  let pos = searchpos(vimshell#get_context().prompt_pattern . '.\?', a:flag)
  if pos[0] != 0
    call cursor(pos[0], matchend(getline(pos[0]),
          \ vimshell#get_context().prompt_pattern . '.\?'))
  else
    call cursor(0, col)
  endif
endfunction"}}}
function! s:delete_previous_output() abort "{{{
  let prompt_pattern = vimshell#get_context().prompt_pattern
  let nprompt = vimshell#get_user_prompt() != '' ?
        \ '^\[%\] ' : prompt_pattern
  let pprompt = prompt_pattern

  " Search next prompt.
  if getline('.') =~ nprompt
    let next_line = line('.')
  elseif vimshell#get_user_prompt() != '' && getline('.') =~ prompt_pattern
    let next_line = searchpos(nprompt, 'bWn')[0]
  else
    let next_line = searchpos(nprompt, 'Wn')[0]
  endif
  while getline(next_line-1) =~ nprompt
    let next_line -= 1
  endwhile

  call cursor(0, 1)
  let prev_line = searchpos(pprompt, 'bWn')[0]
  if prev_line > 0 && next_line - prev_line > 1
    silent execute printf('%s,%sdelete', prev_line+1, next_line-1)
    call append(line('.')-1, "* Output was deleted *")
  endif
  call s:next_prompt()

  call vimshell#terminal#clear_highlight()
endfunction"}}}
function! s:insert_last_word() abort "{{{
  let word = ''
  let histories = vimshell#history#read()
  if !empty(histories)
    for w in reverse(split(histories[-1], '[^\\]\zs\s'))
      if w =~ '[[:alpha:]_/\\]\{2,}'
        let word = w
        break
      endif
    endfor
  endif
  call setline(line('.'), getline('.') . word)
  startinsert!
endfunction"}}}
function! vimshell#mappings#_paste_prompt() abort "{{{
  if !empty(b:vimshell.continuation)
    return vimshell#int_mappings#_paste_prompt()
  endif

  let prompt_pattern = vimshell#get_context().prompt_pattern
  if getline('.') !~# prompt_pattern
    return
  endif

  let command = getline('.')[vimshell#get_prompt_length(getline('.')) :]
  call cursor('$', 0)

  " Set prompt line.
  call vimshell#view#_set_prompt_command(command)
endfunction"}}}
function! s:move_head() abort "{{{
  if !vimshell#check_prompt()
    normal! ^
    return
  endif

  call cursor(0, vimshell#get_prompt_length() + 1)
endfunction"}}}
function! s:move_end_argument() abort "{{{
  let pos = searchpos('\\\@<!\s\zs[^[:space:]]*$', '', line('.'), 'n')
  call cursor(0, pos[1])
endfunction"}}}
function! s:delete_line() abort "{{{
  let col = col('.')
  let mcol = col('$')
  call setline(line('.'), vimshell#get_prompt() . getline('.')[col :])
  call s:move_head()
  if col == mcol-1
    startinsert!
  endif
endfunction"}}}
function! s:clear(is_insert) abort "{{{
  if vimshell#is_interactive()
    return vimshell#int_mappings#clear()
  endif

  let lines = split(vimshell#view#_get_prompt_command(), "\<NL>", 1)

  " Hangup current process.
  call s:hangup(a:is_insert)

  " Clean up the screen.
  % delete _

  call vimshell#terminal#clear_highlight()
  call vimshell#terminal#init()

  call vimshell#print_prompt()
  call vimshell#view#_set_prompt_command(lines[0])
  call append('$', map(lines[1:],
        \ string(vimshell#get_secondary_prompt()).'.v:val'))

  call vimshell#start_insert(a:is_insert)
endfunction"}}}
function! s:expand_wildcard() abort "{{{
  " Wildcard.
  if empty(vimshell#helpers#get_current_args())
    return ''
  endif
  let wildcard = vimshell#helpers#get_current_args()[-1]
  let expanded = vimproc#parser#expand_wildcard(wildcard)

  return (pumvisible() ? "\<C-e>" : '')
        \ . repeat("\<BS>", len(wildcard)) . join(expanded)
endfunction"}}}
function! s:hide() abort "{{{
  " Switch buffer.
  if winnr('$') != 1
    close
  else
    call vimshell#util#alternate_buffer()
  endif
endfunction"}}}
function! s:exit() abort "{{{
  let context = deepcopy(vimshell#get_context())

  call vimshell#interactive#quit_buffer()

  if context.tab
    tabclose
  endif
endfunction"}}}
function! s:delete_backward_char() abort "{{{
  if !pumvisible()
    let prefix = ''
  elseif vimshell#util#is_auto_select()
    let prefix = "\<C-e>"
  else
    let prefix = "\<C-y>"
  endif

  " Prevent backspace over prompt
  let cur_text = vimshell#get_cur_line()
  if cur_text !~# vimshell#get_context().prompt_pattern . '$'
    return prefix . "\<BS>"
  else
    return prefix
  endif
endfunction"}}}
function! s:delete_another_backward_char() abort "{{{
  return vimshell#get_cur_text() != '' ?
        \ s:delete_backward_char() :
        \ winnr('$') != 1 ?
        \ "\<ESC>:close\<CR>" :
        \ "\<ESC>:buffer #\<CR>"
endfunction"}}}
function! s:delete_backward_line() abort "{{{
  if !pumvisible()
    let prefix = ''
  elseif vimshell#util#is_auto_select()
    let prefix = "\<C-e>"
  else
    let prefix = "\<C-y>"
  endif

  let len = len(substitute(vimshell#get_cur_text(), '.', 'x', 'g'))

  return prefix . repeat("\<BS>", len)
endfunction"}}}
function! s:hangup(is_insert) abort "{{{
  if empty(b:vimshell.continuation)
    call vimshell#print_prompt()
    call vimshell#start_insert(a:is_insert)
    return
  endif

  " Kill process.
  call vimshell#interactive#hang_up(bufname('%'))

  let context = {
        \ 'has_head_spaces' : 0,
        \ 'is_interactive' : 1,
        \ 'is_insert' : a:is_insert,
        \ 'fd' : { 'stdin' : '', 'stdout' : '', 'stderr' : '' },
        \ }

  call vimshell#print_prompt(context)
  call vimshell#start_insert(a:is_insert)
endfunction"}}}
function! s:interrupt(is_insert) abort "{{{
  if empty(b:vimshell.continuation)
    call vimshell#print_prompt()
    call vimshell#start_insert(a:is_insert)
    return
  endif

  call vimshell#interactive#send_char(3)
  if !a:is_insert
    stopinsert
  endif
endfunction"}}}
function! s:insert_enter() abort "{{{
  if !vimshell#check_prompt() || !empty(b:vimshell.continuation)
    startinsert
    return
  endif

  if line('.') != line('$')
    " Paste prompt line.
    let save_col = col('.')
    call vimshell#mappings#_paste_prompt()
    call cursor('$', save_col)
  endif

  let prompt_len = vimshell#get_prompt_length()
  if col('.') <= prompt_len
    if prompt_len + 1 >= col('$')
      startinsert!
      return
    else
      call cursor(0, vimshell#get_prompt_length() + 1)
    endif
  endif

  startinsert
endfunction"}}}
function! s:insert_head() abort "{{{
  if !empty(b:vimshell.continuation)
    return vimshell#int_mappings#_insert_head()
  endif

  call cursor(0, 1)
  call s:insert_enter()
endfunction"}}}
function! s:append_enter() abort "{{{
  if vimshell#helpers#check_cursor_is_end()
    call s:append_end()
  else
    call cursor(0, col('.')+1)
    call s:insert_enter()
  endif
endfunction"}}}
function! s:append_end() abort "{{{
  call s:insert_enter()
  startinsert!
endfunction"}}}
function! s:execute_by_background(is_insert) abort "{{{
  if empty(b:vimshell.continuation)
    return
  endif

  let interactive = b:interactive
  let interactive.type = 'interactive'
  let context = b:vimshell.continuation.context

  let b:vimshell.continuation = {}
  let b:interactive = {
        \ 'type' : 'vimshell',
        \ 'syntax' : 'vimshell',
        \ 'process' : {},
        \ 'fd' : context.fd,
        \ 'encoding' : &encoding,
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'hook_functions_table' : {},
        \}

  let [new_pos, old_pos] = vimshell#helpers#split(g:vimshell_split_command)

  call vimshell#commands#iexe#init(context, interactive,
        \ new_pos, old_pos, a:is_insert)
endfunction"}}}
function! s:start_history_complete() abort "{{{
  return
        \ exists('*deoplete#mappings#manual_complete') ?
        \ deoplete#mappings#manual_complete('vimshell_history') :
        \ exists('*neocomplete#start_manual_complete') ?
        \ neocomplete#start_manual_complete('vimshell/history') :
        \ ''
endfunction"}}}

" vim: foldmethod=marker
