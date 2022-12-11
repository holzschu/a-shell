"=============================================================================
" FILE: interactive.vim
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

" Utility functions.

let s:character_regex = ''
let s:update_time_save = &updatetime
let s:READ_SIZE = 10000

augroup vimshell
  autocmd VimLeave * call s:vimleave()
  autocmd CursorMovedI *
        \ call s:check_all_output(0)
  autocmd BufWinEnter,WinEnter *
        \ call s:winenter()
  autocmd BufWinLeave,WinLeave *
        \ call s:winleave(expand('<afile>'))
  autocmd VimResized *
        \ call s:resize()
augroup END

let s:is_insert_char_pre = v:version > 703
      \ || v:version == 703 && has('patch418')
if s:is_insert_char_pre
  autocmd vimshell InsertCharPre *
        \ call s:enable_auto_complete()
endif

let s:use_timer = has('timers')
if !s:use_timer
  autocmd vimshell CursorHold,CursorHoldI *
        \ call s:check_all_output(1)
endif

call vimshell#commands#iexe#define()

" Dummy.
function! vimshell#interactive#init() abort "{{{
endfunction"}}}

function! vimshell#interactive#get_cur_text() abort "{{{
  if !exists('b:interactive')
    return vimshell#get_cur_line()
  endif

  " Get cursor text without prompt.
  return s:chomp_prompt(vimshell#get_cur_line(), line('.'), b:interactive)
endfunction"}}}
function! vimshell#interactive#get_cur_line(line, ...) abort "{{{
  " Get cursor text without prompt.
  let interactive = a:0 > 0 ? a:1 : b:interactive
  return s:chomp_prompt(getline(a:line), a:line, interactive)
endfunction"}}}
function! vimshell#interactive#get_prompt(...) abort "{{{
  let line = get(a:000, 0, line('.'))
  let interactive = get(a:000, 1,
        \ exists('b:interactive') ? b:interactive : {})
  if empty(interactive)
    return ''
  endif

  " Get prompt line.
  return get(get(b:interactive, 'prompt_history', {}), line, '')
endfunction"}}}
function! s:chomp_prompt(cur_text, line, interactive) abort "{{{
  return a:cur_text[len(vimshell#get_prompt(a:line, a:interactive)): ]
endfunction"}}}

function! vimshell#interactive#execute_pty_inout(is_insert) abort "{{{
  let in = vimshell#interactive#get_cur_line(line('.'))
  call vimshell#history#append(in)
  if in !~ "\<C-d>$"
    let in .= vimshell#util#is_windows() ? "\<LF>" : "\<CR>"
  endif

  let b:interactive.prompt_nr = line('.')

  call s:iexe_send_string(in, a:is_insert, line('.'))
endfunction"}}}
function! vimshell#interactive#iexe_send_string(string, is_insert, ...) abort "{{{
  let linenr = get(a:000, 0, line('$'))
  call s:iexe_send_string(a:string, 1, linenr)
endfunction"}}}
function! vimshell#interactive#send_input() abort "{{{
  let input = input('Please input send string: ', vimshell#interactive#get_cur_line(line('.')))
  call vimshell#helpers#imdisable()
  call setline('.', vimshell#interactive#get_prompt() . ' ')

  call cursor(0, col('$')-1)
  call vimshell#interactive#iexe_send_string(input, 1)
endfunction"}}}
function! vimshell#interactive#send_char(char) abort "{{{
  if !s:is_valid(b:interactive)
    return
  endif

  setlocal modifiable

  if type(a:char) != type([])
    let char = nr2char(a:char)
  else
    let char = ''
    for c in a:char
      let char .= nr2char(c)
    endfor
  endif

  call b:interactive.process.stdin.write(char)

  call vimshell#interactive#execute_process_out(1)
endfunction"}}}
function! vimshell#interactive#send_region(line1, line2, string) abort "{{{
  let string = a:string
  if string == ''
    let string = join(getline(a:line1, a:line2), "\<LF>")
  endif
  let string .= "\<LF>"

  return vimshell#interactive#send(string)
endfunction"}}}
function! vimshell#interactive#send(expr) abort "{{{
  if !exists('t:vimshell')
    call vimshell#init#tab_variable()
  endif

  if vimshell#util#is_cmdwin()
    return
  endif

  let last_interactive_bufnr = t:vimshell.last_interactive_bufnr

  if last_interactive_bufnr <= 0
    let command =
          \ has_key(g:vimshell_interactive_interpreter_commands, &filetype) ?
          \ g:vimshell_interactive_interpreter_commands[&filetype] :
          \ input('Please input interpreter command : ',
          \ '', 'customlist,vimshell#helpers#vimshell_execute_complete')
    execute 'VimShellInteractive' command

    let last_interactive_bufnr = t:vimshell.last_interactive_bufnr
    if last_interactive_bufnr <= 0
      " Error.
      return
    endif
  endif

  let winnr = bufwinnr(last_interactive_bufnr)
  if winnr <= 0
    " Open buffer.
    let [new_pos, old_pos] = vimshell#helpers#split(
          \ g:vimshell_split_command)

    execute 'buffer' last_interactive_bufnr
  else
    let [new_pos, old_pos] = vimshell#helpers#split('')
    execute winnr 'wincmd w'
  endif

  let [new_pos[2], new_pos[3]] = [bufnr('%'), getpos('.')]

  " Check alternate buffer.
  let interactive = getbufvar(last_interactive_bufnr,
        \ 'interactive')
  if type(interactive) != type({})
    return
  endif
  let type = interactive.type
  if type !=# 'interactive' && type !=# 'terminal'
        \ && type !=# 'vimshell'
    return
  endif

  call cursor(line('$'), 0)
  call cursor(0, col('$'))

  let list = type(a:expr) == type('') ?
        \ [a:expr] : a:expr

  " Send string.
  if type ==# 'vimshell'
    let string = join(list, '; ')

    if !empty(b:vimshell.continuation)
      if !vimshell#util#input_yesno(
            \ 'The process is running. Kill it?')
        return
      endif

      " Kill process.
      call vimshell#interactive#hang_up(bufname('%'))

      let context = {
            \ 'has_head_spaces' : 0,
            \ 'is_interactive' : 1,
            \ 'is_insert' : 0,
            \ 'fd' : { 'stdin' : '', 'stdout' : '', 'stderr' : '' },
            \ }

      call vimshell#print_prompt(context)
    endif

    let line = substitute(substitute(
          \ string, "\<LF>", '; ', 'g'), '; $', '', '')
    call vimshell#view#_set_prompt_command(line)

    let line = vimshell#hook#call_filter(
          \ 'preparse', vimshell#get_context(), line)
    let ret = vimshell#execute_async(line)

    if ret == 0
      call vimshell#next_prompt(vimshell#get_context(), 0)
    endif
  else
    let string = join(list, "\<LF>")
    if string !~ '\n$'
      let string .= "\<LF>"
    endif

    let prompt = vimshell#interactive#get_prompt(line('$'))
    call setline('$', split(prompt . string, "\<LF>")[0])
    call vimshell#interactive#iexe_send_string(string, mode() ==# 'i')
  endif

  stopinsert
  noautocmd call vimshell#helpers#restore_pos(old_pos)
endfunction"}}}
function! vimshell#interactive#send_string(...) abort "{{{
  echohl WarningMsg | echomsg 'vimshell#interactive#send_string() is deprecated; use vimshell#interactive#send() instead' | echohl None
  return call('vimshell#interactive#send', a:000)
endfunction"}}}
function! s:iexe_send_string(string, is_insert, linenr) abort "{{{
  if !s:is_valid(b:interactive)
    return
  endif

  setlocal modifiable

  let in = a:string

  let context = vimshell#get_context()
  let context.is_interactive = 1

  let in = vimshell#hook#call_filter('preinput', context, in)

  if b:interactive.encoding != ''
        \ && &encoding != b:interactive.encoding
    " Convert encoding.
    let in = vimproc#util#iconv(in, &encoding, b:interactive.encoding)
  endif

  try
    let b:interactive.echoback_linenr = a:linenr

    if in =~ "\<C-d>$"
      " EOF.
      let eof = (b:interactive.is_pty ? "\<C-d>" : "\<C-z>")

      call b:interactive.process.stdin.write(in[:-2] . eof)
    else
      call b:interactive.process.stdin.write(in)
    endif
  catch
    " Error.
    call vimshell#error_line(context.fd, v:exception . ' ' . v:throwpoint)
    call vimshell#interactive#exit()
  endtry

  call vimshell#interactive#execute_process_out(a:is_insert)

  call s:set_output_pos(a:is_insert)

  " Call postinput hook.
  call vimshell#hook#call('postinput', context, in)
endfunction"}}}
function! vimshell#interactive#set_send_buffer(bufname) abort "{{{
  if !exists('t:vimshell')
    call vimshell#init#tab_variable()
  endif

  let bufname = a:bufname == '' ? bufname('%') : a:bufname
  let t:vimshell.last_interactive_bufnr = bufnr(bufname)
endfunction"}}}

function! vimshell#interactive#execute_process_out(is_insert) abort "{{{
  if !s:is_valid(b:interactive)
    return
  endif

  call s:timer_start()

  " Check cache.
  let read = b:interactive.stderr_cache
  if !b:interactive.process.stderr.eof
    let read .= b:interactive.process.stderr.read(s:READ_SIZE, 0)
  endif
  call vimshell#interactive#error_buffer(b:interactive.fd, read)
  let b:interactive.stderr_cache = ''

  " Check cache.
  let read = b:interactive.stdout_cache
  if !b:interactive.process.stdout.eof
    let read .= b:interactive.process.stdout.read(s:READ_SIZE, 0)
  endif
  call vimshell#interactive#print_buffer(b:interactive.fd, read)
  let b:interactive.stdout_cache = ''

  call s:set_output_pos(a:is_insert)

  if b:interactive.process.stdout.eof && b:interactive.process.stderr.eof
    call vimshell#interactive#exit()
  endif
endfunction"}}}
function! s:set_output_pos(is_insert) abort "{{{
  " There are cases when this variable doesn't exist
  " USE: 'b:interactive.is_close_immediately = 1' to replicate
  if !exists('b:interactive')
    return
  end

  if b:interactive.type !=# 'terminal' &&
        \ has_key(b:interactive.process, 'stdout')
        \ && (!b:interactive.process.stdout.eof ||
        \     !b:interactive.process.stderr.eof)
    call vimshell#view#_simple_insert(a:is_insert)

    let b:interactive.output_pos = getpos('.')
  endif
endfunction"}}}

function! vimshell#interactive#quit_buffer() abort "{{{
  if s:is_valid(b:interactive)
    echohl WarningMsg
    let input = input('Process is running. Force exit? [y/N] ')
    echohl None

    if input !~? 'y\%[es]'
      return
    endif

    call vimshell#interactive#force_exit()
  endif

  if b:interactive.type ==# 'terminal'
    call vimshell#commands#texe#restore_cursor()
  endif
  call vimshell#util#delete_buffer()
  call vimshell#echo_error('')

  if winnr('$') != 1
    close
  endif
endfunction"}}}
function! vimshell#interactive#exit() abort "{{{
  if !s:is_valid(b:interactive)
    return
  endif

  " Get status.
  let [cond, status] = s:kill_process(b:interactive)

  let b:interactive.status = str2nr(status)
  let b:interactive.cond = cond

  let interactive = b:interactive
  let context = vimshell#get_context()

  " Call postexit hook.
  call vimshell#hook#call('postexit', context,
        \ [interactive.command, interactive.cmdline])

  if &filetype !=# 'vimshell'
    stopinsert

    if exists('b:interactive.is_close_immediately')
          \ && b:interactive.is_close_immediately
      " Close buffer immediately.
      call vimshell#util#delete_buffer()
    else
      syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
      hi def link InteractiveMessage WarningMsg

      setlocal modifiable
      call append('$', '*Exit*')

      call cursor(line('$'), 0)
    endif
  endif
endfunction"}}}
function! vimshell#interactive#force_exit() abort "{{{
  if !s:is_valid(b:interactive)
    return
  endif

  " Kill processes.
  call s:kill_process(b:interactive)

  if &filetype !=# 'vimshell'
    syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
    hi def link InteractiveMessage WarningMsg

    setlocal modifiable

    call append('$', '*Killed*')
    call cursor(line('$'), 0)
    stopinsert
  endif
endfunction"}}}
function! vimshell#interactive#hang_up(afile) abort "{{{
  let interactive = getbufvar(a:afile, 'interactive')
  let vimshell = getbufvar(a:afile, 'vimshell')
  if !s:is_valid(interactive)
    return
  endif

  call s:kill_process(interactive)
  let interactive.process.is_valid = 0

  if interactive.type ==# 'vimshell'
    " Clear continuation.
    let vimshell.continuation = {}
  endif

  if bufname('%') == a:afile && interactive.type !=# 'vimshell'
    syn match   InteractiveMessage   '\*\%(Exit\|Killed\)\*'
    hi def link InteractiveMessage WarningMsg

    setlocal modifiable

    call append('$', '*Killed*')
    call cursor(line('$'), 0)
    stopinsert
  endif
endfunction"}}}
" function! vimshell#interactive#decode_signal(signal) {{{
let s:_signal_decode_table = {
      \ 2: 'SIGINT',
      \ 3: 'SIGQUIT',
      \ 4: 'SIGILL',
      \ 6: 'SIGABRT',
      \ 8: 'SIGFPE',
      \ 9: 'SIGKILL',
      \ 11: 'SIGSEGV',
      \ 13: 'SIGPIPE',
      \ 14: 'SIGALRM',
      \ 15: 'SIGTERM',
      \ 10: 'SIGUSR1',
      \ 12: 'SIGUSR2',
      \ 17: 'SIGCHLD',
      \ 18: 'SIGCONT',
      \ 19: 'SIGSTOP',
      \ 20: 'SIGTSTP',
      \ 21: 'SIGTTIN',
      \ 22: 'SIGTTOU'}
function! vimshell#interactive#decode_signal(signal) abort
  return get(s:_signal_decode_table, a:signal, 'UNKNOWN')
endfunction " }}}
function! vimshell#interactive#read(fd) abort "{{{
  if empty(a:fd) || a:fd.stdin == ''
    return ''
  endif

  if a:fd.stdout == '/dev/null'
    " Nothing.
    return ''
  elseif a:fd.stdout == '/dev/clip'
    " Write to clipboard.
    return @+
  else
    " Read from file.
    if !vimshell#util#is_windows()
      let ff = "\<CR>\<LF>"
    else
      let ff = "\<LF>"
    endif

    return join(readfile(a:fd.stdin), ff) . ff
  endif
endfunction"}}}
function! vimshell#interactive#print_buffer(fd, string) abort "{{{
  if a:string == '' || !exists('b:interactive')
        \|| !&l:modifiable
    return
  endif

  if !empty(a:fd) && a:fd.stdout != ''
    let mode = 'w'
    let fd = a:fd.stdout
    if fd =~ '^>'
      let mode = 'a'
      let fd = fd[1:]
    endif
    return vimproc#write(fd, a:string, mode)
  endif

  " Convert encoding.
  let string =
        \ (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ vimproc#util#iconv(a:string, b:interactive.encoding, &encoding) : a:string

  call vimshell#terminal#print(string, 0)

  call s:check_password_input(string)

  call s:check_scrollback()

  let b:interactive.output_pos = getpos('.')

  if has_key(b:interactive, 'prompt_history')
        \ && line('.') != b:interactive.echoback_linenr && getline('.') != ''
    let b:interactive.prompt_history[line('.')] = getline('.')
  endif
endfunction"}}}
function! vimshell#interactive#error_buffer(fd, string) abort "{{{
  if a:string == ''
    return
  endif

  if !exists('b:interactive') || !&l:modifiable
    echohl WarningMsg | echomsg a:string | echohl None
    return
  endif

  if !empty(a:fd) && a:fd.stderr != ''
    let mode = 'w'
    let fd = a:fd.stderr
    if fd =~ '^>'
      let mode = 'a'
      let fd = fd[1:]
    endif
    return vimproc#write(fd, a:string, mode)
  endif

  " Convert encoding.
  let string =
        \ (b:interactive.encoding != '' && &encoding != b:interactive.encoding) ?
        \ vimproc#util#iconv(a:string, b:interactive.encoding, &encoding) : a:string

  " Print buffer.
  call vimshell#terminal#print(string, 1)

  call s:check_password_input(string)

  call s:check_scrollback()

  let b:interactive.output_pos = getpos('.')

  redraw

  if has_key(b:interactive, 'prompt_history')
        \ && line('.') != b:interactive.echoback_linenr && getline('.') != ''
    let b:interactive.prompt_history[line('.')] = getline('.')
  endif
endfunction"}}}
function! s:check_password_input(string) abort "{{{
  let current_line = substitute(getline('.'), '!!!', '', 'g')

  if !exists('g:vimproc_password_pattern')
        \ || (current_line !~# g:vimproc_password_pattern
        \ && a:string !~# g:vimproc_password_pattern)
        \ || (b:interactive.type != 'interactive'
        \     && b:interactive.type != 'vimshell')
        \ || a:string[matchend(a:string,
        \ g:vimproc_password_pattern) :] =~ '\n'
    return
  endif

  redraw

  " Password input.
  set imsearch=0
  let in = inputsecret('Input Secret : ')

  if b:interactive.encoding != '' && &encoding != b:interactive.encoding
    " Convert encoding.
    let in = vimproc#util#iconv(in, &encoding, b:interactive.encoding)
  endif

  try
    call b:interactive.process.stdin.write(in . "\<NL>")
  catch
    call b:interactive.process.waitpid()

    " Error.
    let context = vimshell#get_context()
    call vimshell#error_line(context.fd, v:exception . ' ' . v:throwpoint)
    let b:vimshell.continuation = {}
    call vimshell#print_prompt(context)
    call vimshell#start_insert(mode() ==# 'i')
  endtry
endfunction"}}}

function! s:check_scrollback() abort "{{{
  let prompt_nr = get(b:interactive, 'prompt_nr', 0)
  let output_lines = line('.') - prompt_nr
  if output_lines > g:vimshell_scrollback_limit
    let pos = getpos('.')
    " Delete output.
    silent execute printf('%d,%ddelete _', prompt_nr+1,
          \ (line('.')-g:vimshell_scrollback_limit+1))
    if pos != getpos('.')
      call setpos('.', pos)
    endif
  endif
endfunction"}}}

function! vimshell#interactive#get_default_encoding(commands) abort "{{{
  if empty(a:commands[0].args)
    return ''
  endif

  let full_command = tolower(
        \ vimshell#helpers#get_command_path(a:commands[0].args[0]))
  let command = fnamemodify(full_command, ':t:r')
  for [path, encoding] in items(g:vimshell_interactive_encodings)
    if (path =~ '/' && stridx(full_command, tolower(path)) >= 0)
          \ || path ==? command
      return encoding
    endif
  endfor

  " Default.
  return 'char'
endfunction"}}}

" Autocmd functions.
function! s:check_all_output(is_hold) abort "{{{
  if vimshell#util#is_cmdwin()
    return
  endif

  let interactive = {}
  if mode() ==# 'n'
    for bufnr in filter(range(1, bufnr('$')),
          \ "type(getbufvar(v:val, 'interactive')) == type({})")
      " Check output.
      call s:check_output(getbufvar(bufnr, 'interactive'),
            \ bufnr, bufnr('%'))
      if bufwinnr(bufnr) > 0
        let interactive = getbufvar(bufnr, 'interactive')
      endif
    endfor
  elseif mode() ==# 'i'
        \ && exists('b:interactive') && line('.') == line('$')
    let interactive = b:interactive
    call s:check_output(interactive, bufnr('%'), bufnr('%'))
  endif

  if !s:is_insert_char_pre && exists('b:interactive')
        \ && vimshell#get_prompt() != ''
    " For old Vim.
    call vimshell#util#enable_auto_complete()
  endif

  if !s:use_timer
    call s:dummy_output(interactive, a:is_hold)
  endif
endfunction"}}}
function! s:check_output(interactive, bufnr, bufnr_save) abort "{{{
  " Output cache.
  if exists('b:interactive') && (s:is_skk_enabled()
        \ || (b:interactive.type ==# 'interactive'
        \   && line('.') != b:interactive.echoback_linenr
        \   && (vimshell#interactive#get_cur_line(
        \             line('.'), b:interactive) != ''
        \    || vimshell#interactive#get_cur_line(
        \            line('$'), b:interactive) != '')))
    return 1
  endif

  if a:interactive.type ==# 'less'
        \ || (!s:cache_output(a:interactive) && !exists('b:interactive'))
        \ || vimshell#util#is_cmdwin()
        \ || (a:bufnr != a:bufnr_save && bufwinnr(a:bufnr) < 0)
    return
  endif

  if a:bufnr != a:bufnr_save
    execute bufwinnr(a:bufnr) . 'wincmd w'
  endif

  let type = a:interactive.type

  if (type ==# 'vimshell'
        \   && empty(b:vimshell.continuation))
    if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
      execute bufwinnr(a:bufnr_save) . 'wincmd w'
    endif

    return
  endif

  let pos = getpos('.')
  let is_last_line = line('.') == line('$')
  if has_key(a:interactive, 'output_pos')
    call setpos('.', a:interactive.output_pos)
  endif

  let is_insert = mode() ==# 'i'

  if type ==# 'background'
    setlocal modifiable
    call vimshell#interactive#execute_process_out(is_insert)
    setlocal nomodifiable
  elseif type ==# 'vimshell'
    try
      call vimshell#parser#execute_continuation(is_insert)
    catch
      " Error.
      let context = vimshell#get_context()
      if v:exception !~# '^Vim:Interrupt'
        call vimshell#error_line(
              \ context.fd, v:exception . ' ' . v:throwpoint)
      endif
      let b:vimshell.continuation = {}
      call vimshell#print_prompt(context)
      call vimshell#start_insert(is_insert)
    endtry
  elseif type ==# 'interactive' || type ==# 'terminal'
    setlocal modifiable

    call vimshell#interactive#execute_process_out(is_insert)

    if type ==# 'terminal'
      setlocal nomodifiable
    elseif (!a:interactive.process.stdout.eof
          \   || !a:interactive.process.stderr.eof)
          \ && is_insert
      call vimshell#view#_simple_insert(is_insert)
    endif
  endif

  if (!is_last_line || vimshell#interactive#get_cur_text() != '')
        \ && pos != getpos('.')
        \ && exists('b:interactive')
        \ && b:interactive.process.is_valid
    call setpos('.', pos)
  endif

  " Check window size.
  if vimshell#helpers#get_winwidth() != a:interactive.width
    " Set new window size.
    call a:interactive.process.set_winsize(
          \ vimshell#helpers#get_winwidth(), g:vimshell_scrollback_limit)
  endif

  if a:bufnr != a:bufnr_save && bufexists(a:bufnr_save)
    execute bufwinnr(a:bufnr_save) . 'wincmd w'
  endif
endfunction"}}}
function! s:cache_output(interactive) abort "{{{
  if empty(a:interactive.process) ||
        \ !a:interactive.process.is_valid
    return 0
  endif

  if !a:interactive.process.stdout.eof
    let a:interactive.stdout_cache .=
          \ a:interactive.process.stdout.read(s:READ_SIZE, 0)
  endif

  if !a:interactive.process.stderr.eof
    let a:interactive.stderr_cache .=
          \ a:interactive.process.stderr.read(s:READ_SIZE, 0)
  endif

  if a:interactive.process.stderr.eof &&
        \ a:interactive.process.stdout.eof
    return 2
  endif

  return a:interactive.stdout_cache != '' ||
        \ a:interactive.stderr_cache != ''
endfunction"}}}
function! s:is_skk_enabled() abort "{{{
  return (exists('b:skk_on') && b:skk_on)
        \ || (exists('*eskk#is_enabled') && eskk#is_enabled())
endfunction"}}}
function! s:enable_auto_complete() abort "{{{
  if exists('b:interactive') && v:char != ']'
    call vimshell#util#enable_auto_complete()
  endif
endfunction"}}}
function! s:dummy_output(interactive, is_hold) abort "{{{
  if s:is_valid(a:interactive)
    if g:vimshell_interactive_update_time > 0
          \ && &updatetime > g:vimshell_interactive_update_time
      " Change updatetime.
      let s:update_time_save = &updatetime
      let &updatetime = g:vimshell_interactive_update_time
    endif

    if mode() ==# 'n'
      call feedkeys("g\<ESC>" . (v:count > 0 ? v:count : ''), 'n')
    elseif mode() ==# 'i'
      let is_complete_hold = vimshell#util#is_complete_hold()
      if a:is_hold != is_complete_hold
            \ || !has('gui_running') || has('nvim')
        setlocal modifiable
        " Prevent screen flick
        if has('nvim')
          " In neovim, t_vb does not work
          set novisualbell t_vb=
        else
          set visualbell t_vb=
        endif
        call feedkeys("]\<BS>", 'n')
      endif
    endif
  elseif g:vimshell_interactive_update_time > 0
        \ && &updatetime == g:vimshell_interactive_update_time
        \ && &filetype !=# 'unite'
    " Restore updatetime.
    let &updatetime = s:update_time_save
  endif
endfunction"}}}
function! s:timer_handler(timer) abort "{{{
  call s:check_all_output(0)
endfunction"}}}
function! s:timer_start() abort "{{{
  if !exists('s:timer') && s:use_timer
    let s:timer = timer_start((g:vimshell_interactive_update_time > 0 ?
          \ g:vimshell_interactive_update_time : &updatetime),
          \ function('s:timer_handler'), {'repeat': -1})
    autocmd vimshell VimLeavePre * call s:timer_stop()
  endif
endfunction"}}}
function! s:timer_stop() abort "{{{
  if exists('s:timer')
    call timer_stop(s:timer)
    unlet s:timer
  endif
endfunction"}}}

function! s:winenter() abort "{{{
  if exists('b:interactive')
    call vimshell#terminal#set_title()
    if !exists('b:vimshell') || !empty(b:vimshell.continuation)
      call s:timer_start()
    endif
  endif

  let check_interactive = empty(filter(range(1, bufnr('$')),
        \ "s:is_valid(getbufvar(v:val, 'interactive'))"))
  if check_interactive
        \ && (!exists('b:interactive') || (exists('b:vimshell')
        \     && empty(b:vimshell.continuation)))
    call s:timer_stop()
  endif

  call s:resize()
endfunction"}}}
function! s:winleave(bufname) abort "{{{
  if !exists('b:interactive')
    return
  endif

  if !exists('t:vimshell')
    call vimshell#init#tab_variable()
  endif

  let t:vimshell.last_interactive_bufnr = bufnr(a:bufname)

  call vimshell#terminal#restore_title()
endfunction"}}}
function! s:vimleave() abort "{{{
  " Kill all processes.
  for interactive in map(filter(range(1, bufnr('$')),
        \ "type(getbufvar(v:val, 'interactive')) == type({})
        \  && get(get(getbufvar(v:val, 'interactive'),
        \     'process', {}), 'is_valid', 0)"),
        \ "getbufvar(v:val, 'interactive')")
    call s:kill_process(interactive)
  endfor
endfunction"}}}
function! s:resize() abort "{{{
  if exists('b:interactive') && !empty(b:interactive.process)
    call b:interactive.process.set_winsize(
          \ vimshell#helpers#get_winwidth(), g:vimshell_scrollback_limit)
  endif
endfunction"}}}

function! s:is_valid(interactive) abort "{{{
  return type(a:interactive) == type({})
        \ && !empty(a:interactive)
        \ && !empty(a:interactive.process)
        \ && a:interactive.process.is_valid
endfunction"}}}

function! s:kill_process(interactive) abort "{{{
  " Get status.
  let [cond, status] = a:interactive.process.waitpid()
  if cond != 'exit'
    try
      " Kill process.
      " 15 == SIGTERM
      call a:interactive.process.kill(g:vimproc#SIGTERM)
      call a:interactive.process.waitpid()
    catch
    endtry
  endif

  return [cond, status]
endfunction"}}}

" vim: foldmethod=marker
