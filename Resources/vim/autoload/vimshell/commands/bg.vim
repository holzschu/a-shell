"=============================================================================
" FILE: bg.vim
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

let s:manager = vimshell#util#get_vital().import('Vim.Buffer')

let s:command = {
      \ 'name' : 'bg',
      \ 'kind' : 'execute',
      \ 'description' : 'bg [{option}...] {command}',
      \}
function! s:command.execute(commands, context) abort "{{{
  " Execute command in background.
  if empty(a:commands)
    return
  endif

  let commands = a:commands
  let [commands[0].args, options] = vimshell#parser#getopt(commands[0].args, {
        \ 'arg=' : ['--encoding', '--split', '--filetype'],
        \ }, {
        \ '--encoding' : vimshell#interactive#get_default_encoding(a:commands),
        \ '--split' : g:vimshell_split_command,
        \ '--filetype' : 'background',
        \ })

  if empty(commands[0].args)
    return
  endif

  if len(commands[0].args) == 1
        \ && (vimshell#util#is_windows() || !executable(commands[0].args[0]))
    let ext = fnamemodify(commands[0].args[0], ':e')
    if has_key(g:vimshell_execute_file_list, ext)
      " Use g:vimshell_execute_file_list
      let commands[0].args =
            \ [g:vimshell_execute_file_list[ext], commands[0].args[0]]
    endif
  endif

  " Background execute.
  if exists('b:interactive') &&
        \ !empty(b:interactive.process) && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  " Encoding conversion.
  if options['--encoding'] != '' && options['--encoding'] != &encoding
    for command in commands
      call map(command.args, 'vimproc#util#iconv(v:val, &encoding, options["--encoding"])')
    endfor
  endif

  " Set environment variables.
  let environments_save = vimshell#util#set_variables({
        \ '$TERM' : g:vimshell_environment_term,
        \ '$TERMCAP' : 'COLUMNS=' . vimshell#helpers#get_winwidth(),
        \ '$VIMSHELL' : 1,
        \ '$COLUMNS' : vimshell#helpers#get_winwidth(),
        \ '$LINES' : g:vimshell_scrollback_limit,
        \ '$VIMSHELL_TERM' : 'background',
        \ '$EDITOR' : vimshell#helpers#get_editor_name(),
        \ '$GIT_EDITOR' : vimshell#helpers#get_editor_name(),
        \ '$PAGER' : g:vimshell_cat_command,
        \ '$GIT_PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let sub = vimproc#plineopen3(commands)

  " Restore environment variables.
  call vimshell#util#restore_variables(environments_save)

  " Set variables.
  let interactive = {
        \ 'type' : 'background',
        \ 'syntax' : &syntax,
        \ 'process' : sub,
        \ 'fd' : a:context.fd,
        \ 'encoding' : options['--encoding'],
        \ 'is_pty' : 0,
        \ 'command' : commands[0].args[0],
        \ 'cmdline' : join(commands[0].args),
        \ 'echoback_linenr' : 0,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'width' : vimshell#helpers#get_winwidth(),
        \ 'height' : g:vimshell_scrollback_limit,
        \ 'hook_functions_table' : {},
        \}

  " Input from stdin.
  if interactive.fd.stdin != ''
    call interactive.process.stdin.write(
          \ vimshell#interactive##read(a:context.fd))
  endif
  call interactive.process.stdin.close()

  return vimshell#commands#bg#init(a:commands, a:context, options, interactive)
endfunction"}}}
function! s:command.complete(args) abort "{{{
  return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! vimshell#commands#bg#define() abort
  return s:command
endfunction

function! vimshell#commands#bg#init(commands, context, options, interactive) abort "{{{
  " Save current directiory.
  let cwd = getcwd()

  let [new_pos, old_pos] = vimshell#helpers#split(a:options['--split'])

  let args = ''
  for command in a:commands
    let args .= join(command.args)
  endfor

  let loaded = s:manager.open('bg-'.substitute(args,
        \ '[<>|]', '_', 'g') .'@'.(bufnr('$')+1), 'silent edit')
  if !loaded
    call vimshell#echo_error(
          \ '[vimshell] Failed to open Buffer.')
    return
  endif

  let [new_pos[2], new_pos[3]] = [bufnr('%'), getpos('.')]

  " Common.
  call vimshell#init#_default_settings()

  " For bg.
  setlocal nomodifiable
  let &filetype = a:options['--filetype']

  let b:interactive = a:interactive

  call vimshell#cd(cwd)

  " Set syntax.
  syn region   InteractiveError   start=+!!!+ end=+!!!+
        \ contains=InteractiveErrorHidden oneline
  if v:version >= 703
    " Supported conceal features.
    syn match   InteractiveErrorHidden            '!!!' contained conceal
  else
    syn match   InteractiveErrorHidden            '!!!' contained
  endif
  hi def link InteractiveErrorHidden Error

  augroup vimshell
    autocmd BufDelete,VimLeavePre <buffer>
          \ call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd BufWinEnter,WinEnter <buffer> call s:event_bufwin_enter()
  augroup END

  nnoremap <buffer><silent> <Plug>(vimshell_interactive_execute_line)
        \ :<C-u>call <SID>on_execute()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_interrupt)
        \ :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_interactive_exit)
        \ :<C-u>call vimshell#interactive#quit_buffer()<CR>

  nmap <buffer><CR>      <Plug>(vimshell_interactive_execute_line)
  nmap <buffer><C-c>     <Plug>(vimshell_interactive_interrupt)
  nmap <buffer>q         <Plug>(vimshell_interactive_exit)

  call s:on_execute()

  noautocmd call vimshell#helpers#restore_pos(old_pos)

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#next_prompt(a:context, 0)
    noautocmd call vimshell#helpers#restore_pos(new_pos)
    stopinsert
  endif
endfunction"}}}

function! s:on_execute() abort "{{{
  setlocal modifiable
  echo 'Running command.'
  call vimshell#interactive#execute_process_out(mode() ==# 'i')
  redraw
  echo ''
  setlocal nomodifiable
endfunction"}}}
function! s:on_exit() abort "{{{
  if !b:interactive.process.is_valid
    call vimshell#util#delete_buffer()
  endif
endfunction "}}}
function! s:event_bufwin_enter() abort "{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
endfunction"}}}
