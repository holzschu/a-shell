"=============================================================================
" FILE: int_mappings.vim
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

function! vimshell#int_mappings#define_default_mappings() abort "{{{
  " Plugin key-mappings. "{{{
  nnoremap <buffer><silent> <Plug>(vimshell_int_previous_prompt)
        \ :<C-u>call <SID>previous_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_next_prompt)
        \ :<C-u>call <SID>next_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_execute_line)
        \ :<C-u>call vimshell#execute_current_line(0)<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_paste_prompt)
        \ :<C-u>call vimshell#int_mappings#_paste_prompt()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_hangup)
        \ :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_exit)
        \ :<C-u>call vimshell#interactive#quit_buffer()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_restart_command)
        \ :<C-u>call <SID>restart_command()<CR>
  nnoremap <buffer><expr> <Plug>(vimshell_int_change_line)
        \ (vimshell#interactive#get_prompt() == '') ? 'ddO' :
        \ printf('0%dlc$', vimshell#util#strchars(
        \   vimshell#interactive#get_prompt()))
  nmap <buffer>  <Plug>(vimshell_int_delete_line)
        \ <Plug>(vimshell_int_change_line)<ESC>
  nnoremap <silent><buffer> <Plug>(vimshell_int_insert_enter)
        \ :<C-u>call <SID>insert_enter()<CR>
  nnoremap <silent><buffer> <Plug>(vimshell_int_insert_head)
        \ :<C-u>call <SID>insert_head()<CR>
  nnoremap <silent><buffer> <Plug>(vimshell_int_append_enter)
        \ :<C-u>call <SID>append_enter()<CR>
  nnoremap <silent><buffer> <Plug>(vimshell_int_append_end)
        \ :<C-u>call <SID>append_end()<CR>
  nnoremap <silent><buffer> <Plug>(vimshell_int_clear)
        \ :<C-u>call vimshell#int_mappings#clear()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_int_interrupt)
        \ :<C-u>call vimshell#interactive#send_char(3)<CR>

  inoremap <buffer><silent> <Plug>(vimshell_int_move_head)
        \ <ESC>:<C-u>call <SID>move_head()<CR>
  inoremap <buffer><expr> <Plug>(vimshell_int_delete_backward_line)
        \ <SID>delete_backward_line()
  inoremap <buffer><expr> <Plug>(vimshell_int_delete_backward_word)
        \ vimshell#interactive#get_cur_text()  == '' ? '' : "\<C-w>"
  inoremap <buffer><silent> <Plug>(vimshell_int_execute_line)
        \ <C-g>u<C-o>:call vimshell#execute_current_line(1)<CR>
        " \ <C-g>u<ESC>:<C-u>call vimshell#execute_current_line(1)<CR>
  inoremap <buffer><expr> <Plug>(vimshell_int_delete_backward_char)
        \ <SID>delete_backward_char(0)
  " 3 == char2nr("\<C-c>")
  inoremap <buffer><silent> <Plug>(vimshell_int_interrupt)
        \ <C-o>:call vimshell#interactive#send_char(3)<CR>
  inoremap <buffer><expr> <Plug>(vimshell_int_another_delete_backward_char)
        \ <SID>delete_backward_char(1)
  inoremap <buffer><silent> <Plug>(vimshell_int_send_input)
        \ <C-o>:call vimshell#interactive#send_input()<CR>
  inoremap <buffer><expr> <SID>(bs-ctrl-])
        \ getline('.')[col('.') - 2] ==# "\<C-]>" ? "\<BS>" : ''
  inoremap <buffer><silent> <Plug>(vimshell_int_command_complete)
        \ <C-o>:call vimshell#int_mappings#command_complete()<CR>
  inoremap <buffer><expr> <Plug>(vimshell_int_delete_forward_line)
        \ col('.') == col('$') ? "" : "\<ESC>lDa"
  inoremap <buffer><expr><silent>
        \ <Plug>(vimshell_int_history_unite)
        \ unite#sources#vimshell_history#start_complete(!0)
  "}}}

  if get(g:, 'vimshell_no_default_keymappings', 0)
    return
  endif

  " Normal mode key-mappings.
  nmap <buffer> <C-p>     <Plug>(vimshell_int_previous_prompt)
  nmap <buffer> <C-n>     <Plug>(vimshell_int_next_prompt)
  nmap <buffer> <CR>      <Plug>(vimshell_int_execute_line)
  nmap <buffer> <C-y>     <Plug>(vimshell_int_paste_prompt)
  nmap <buffer> <C-z>     <Plug>(vimshell_int_restart_command)
  nmap <buffer> <C-c>     <Plug>(vimshell_int_interrupt)
  nmap <buffer> q         <Plug>(vimshell_int_exit)
  nmap <buffer> cc         <Plug>(vimshell_int_change_line)
  nmap <buffer> dd         <Plug>(vimshell_int_delete_line)
  nmap <buffer> I         <Plug>(vimshell_int_insert_head)
  nmap <buffer> A         <Plug>(vimshell_int_append_end)
  nmap <buffer> i         <Plug>(vimshell_int_insert_enter)
  nmap <buffer> a         <Plug>(vimshell_int_append_enter)
  nmap <buffer> <C-l>     <Plug>(vimshell_int_clear)

  " Insert mode key-mappings.
  imap <buffer> <C-h>     <Plug>(vimshell_int_delete_backward_char)
  imap <buffer> <BS>     <Plug>(vimshell_int_delete_backward_char)
  imap <buffer> <C-a>     <Plug>(vimshell_int_move_head)
  imap <buffer> <C-u>     <Plug>(vimshell_int_delete_backward_line)
  imap <buffer> <C-w>     <Plug>(vimshell_int_delete_backward_word)
  imap <buffer> <C-k>     <Plug>(vimshell_int_delete_forward_line)
  imap <buffer> <C-]>               <C-]><SID>(bs-ctrl-])
  imap <buffer> <CR>      <C-]><Plug>(vimshell_int_execute_line)
  imap <buffer> <C-c>     <Plug>(vimshell_int_interrupt)
  imap <buffer> <C-l>     <Plug>(vimshell_int_history_unite)
  imap <buffer> <C-v>  <Plug>(vimshell_int_send_input)
  inoremap <buffer> <C-n>     <C-n>
  imap <buffer><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ "\<Plug>(vimshell_int_command_complete)"
endfunction"}}}

" vimshell interactive key-mappings functions.
function! s:delete_backward_char(is_auto_select) abort "{{{
  if !pumvisible()
    let prefix = ''
  elseif a:is_auto_select ||
        \ vimshell#util#is_auto_select()
    let prefix = "\<C-e>"
  else
    let prefix = "\<C-y>"
  endif

  " Prevent backspace over prompt
  let cur_text = vimshell#get_cur_line()
  if !has_key(b:interactive.prompt_history, line('.'))
        \ || cur_text !=# b:interactive.prompt_history[line('.')]
    return prefix . "\<BS>"
  else
    return prefix
  endif
endfunction"}}}
function! s:previous_prompt() abort "{{{
  let prompts = sort(filter(map(keys(b:interactive.prompt_history), 'str2nr(v:val)'),
        \ 'v:val < line(".")'))
  if !empty(prompts)
    call cursor(prompts[-1], len(vimshell#interactive#get_prompt()) + 1)
  endif
endfunction"}}}
function! s:next_prompt() abort "{{{
  let prompts = sort(filter(map(keys(b:interactive.prompt_history),
        \ 'str2nr(v:val)'), 'v:val > line(".")'))
  if !empty(prompts)
    call cursor(prompts[0], len(vimshell#interactive#get_prompt()) + 1)
  endif
endfunction"}}}
function! s:move_head() abort "{{{
  call vimshell#int_mappings#_insert_head()
endfunction"}}}
function! s:delete_backward_line() abort "{{{
  if !pumvisible()
    let prefix = ''
  elseif vimshell#util#is_auto_select()
    let prefix = "\<C-e>"
  else
    let prefix = "\<C-y>"
  endif

  let len = !has_key(b:interactive.prompt_history, line('.')) ?
        \ len(getline('.')) :
        \ len(substitute(vimshell#interactive#get_cur_text(), '.', 'x', 'g'))

  return prefix . repeat("\<BS>", len)
endfunction"}}}
function! vimshell#int_mappings#execute_line(is_insert) abort "{{{
  call vimshell#util#disable_auto_complete()

  if !has_key(b:interactive.prompt_history, line('.'))
    " Do update.
    call vimshell#interactive#execute_process_out(a:is_insert)
  endif

  if line('.') != line('$')
    call vimshell#int_mappings#_paste_prompt()
  endif

  call cursor(line('$'), 0)
  call cursor(0, col('$'))

  call vimshell#interactive#execute_pty_inout(a:is_insert)

  call vimshell#helpers#imdisable()
endfunction"}}}
function! vimshell#int_mappings#_paste_prompt() abort "{{{
  if !has_key(b:interactive.prompt_history, line('.'))
    return
  endif

  " Set prompt line.
  let cur_text = vimshell#interactive#get_cur_line(line('.'))
  call setline(line('$'), vimshell#interactive#get_prompt(line('$')) . cur_text)
  call cursor(line('$'), 0)
  call cursor(0, col('$'))
endfunction"}}}
function! s:restart_command() abort "{{{
  if exists('b:interactive') && !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  set modifiable
  " Clean up the screen.
  % delete _
  call vimshell#terminal#clear_highlight()

  " Initialize.
  let sub = vimproc#ptyopen(b:interactive.args)

  call s:default_settings()

  " Set variables.
  call extend(b:interactive, {
        \ 'process' : sub,
        \ 'is_secret': 0,
        \ 'prompt_history' : {},
        \ 'echoback_linenr' : 0
        \}, 'force')

  call vimshell#interactive#execute_process_out(1)

  call vimshell#view#_start_insert()
endfunction"}}}
function! vimshell#int_mappings#command_complete() abort "{{{
  let prompt = vimshell#interactive#get_prompt()
  let cur_text = vimshell#interactive#get_cur_text()
  call setline('.', prompt)
  let prompt_linenr = line('.')

  call vimshell#interactive#iexe_send_string(cur_text .
        \ (b:interactive.is_pty ? "\<TAB>" : "\<TAB>\<TAB>"), !0, 0)

  " if !vimshell#util#head_match(getline(prompt_linenr), prompt)
  "   " Restore prompt.
  "   call setline(prompt_linenr, prompt . cur_text .
  "         \  getline(prompt_linenr))
  "   startinsert!
  " endif

  let b:interactive.prompt_history[prompt_linenr] =
   \ getline(prompt_linenr)
endfunction "}}}
function! s:insert_enter() abort "{{{
  if !has_key(b:interactive.prompt_history, line('.')) && line('.') != line('$')
    startinsert
    return
  endif

  if col('.') <= len(vimshell#interactive#get_prompt())
    if len(vimshell#interactive#get_prompt()) + 1 >= col('$')
      startinsert!
      return
    else
      call cursor(0, len(vimshell#interactive#get_prompt()) + 1)
    endif
  endif

  startinsert
endfunction"}}}
function! vimshell#int_mappings#_insert_head() abort "{{{
  call cursor(0, 1)
  call s:insert_enter()
endfunction"}}}
function! s:append_enter() abort "{{{
  if vimshell#helpers#check_cursor_is_end()
    call s:append_end()
  else
    call cursor(0, col('.') + 1)
    call s:insert_enter()
  endif
endfunction"}}}
function! s:append_end() abort "{{{
  call s:insert_enter()
  startinsert!
endfunction"}}}
function! s:send_intrrupt() abort "{{{
endfunction"}}}
function! vimshell#int_mappings#clear() abort "{{{
  set modifiable

  " Clean up the screen.
  if line('$') != 1
    if has_key(b:interactive.prompt_history, line('$'))
      let current_history = b:interactive.prompt_history[line('$')]

      let b:interactive.prompt_history = {}

      " Restore history.
      let b:interactive.prompt_history[1] = current_history
    else
      let b:interactive.prompt_history = {}
    endif

    1,$-1 delete _
  else
    " Clear prompt history.
    let b:interactive.prompt_history = {}

    % delete _
  endif

  let b:interactive.echoback_linenr = 0

  " Clear.
  call vimshell#terminal#clear_highlight()
  call vimshell#terminal#init()

  call vimshell#interactive#execute_process_out(1)

  call vimshell#view#_start_insert()
endfunction"}}}

" vim: foldmethod=marker
