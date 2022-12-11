"=============================================================================
" FILE: iexe.vim
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
      \ 'name' : 'iexe',
      \ 'kind' : 'execute',
      \ 'description' : 'iexe [{options}...] {command}',
      \}
function! s:command.execute(commands, context) abort "{{{
  " Interactive execute command.
  if empty(a:commands)
    return
  endif

  let commands = a:commands
  let [commands[0].args, options] = vimshell#parser#getopt(commands[0].args, {
        \ 'arg=' : ['--encoding', '--split'],
        \ }, {
        \ '--encoding' : vimshell#interactive#get_default_encoding(a:commands),
        \ '--split' : g:vimshell_split_command,
        \ })

  let args = commands[0].args

  if empty(args)
    return
  endif

  if has_key(g:vimshell_interactive_cygwin_commands, fnamemodify(args[0], ':r'))
    " Use Cygwin pty.
    call insert(args, 'fakecygpty')
  endif

  let use_cygpty = vimshell#util#is_windows() &&
        \ args[0] =~ '^fakecygpty\%(\.exe\)\?$'
  if use_cygpty
    if !executable('fakecygpty')
      call vimshell#error_line(a:context.fd,
            \ 'iexe: "fakecygpty.exe" is required. Please install it.')
      return
    endif

    " Get program path from g:vimshell_interactive_cygwin_path.
    if len(args) < 2
      call vimshell#error_line(a:context.fd, 'iexe: command is required.')
      return
    endif

    let args[1] = vimproc#get_command_name(
          \ args[1], g:vimshell_interactive_cygwin_path)
  endif

  let cmdname = fnamemodify(args[0], ':r')
  if !use_cygpty && has_key(g:vimshell_interactive_command_options, cmdname)
    for arg in vimproc#parser#split_args(
          \ g:vimshell_interactive_command_options[cmdname])
      call add(args, arg)
    endfor
  endif

  if vimshell#util#is_windows() && cmdname == 'cmd'
    " Run cmdproxy.exe instead of cmd.exe.
    if !executable('cmdproxy.exe')
      call vimshell#error_line(a:context.fd,
            \ 'iexe: "cmdproxy.exe" is not found. Please install it.')
      return
    endif

    let args[0] = 'cmdproxy.exe'
  endif

  " Encoding conversion.
  if options['--encoding'] != '' && options['--encoding'] != &encoding
    for command in commands
      call map(command.args,
            \ 'vimproc#util#iconv(v:val, &encoding, options["--encoding"])')
    endfor
  endif

  if exists('b:interactive') && !empty(b:interactive.process)
        \ && b:interactive.process.is_valid
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  " Initialize.
  let home_save = {}
  if use_cygpty && g:vimshell_interactive_cygwin_home != ''
    " Set $HOME.
    let home_save = vimshell#util#set_variables({
          \ '$HOME' : g:vimshell_interactive_cygwin_home,
          \})
  endif

  try
    let [new_pos, old_pos] = vimshell#helpers#split(options['--split'])

    " Set environment variables.
    let environments_save = vimshell#util#set_variables({
          \ '$TERM' : g:vimshell_environment_term,
          \ '$TERMCAP' : 'COLUMNS=' . vimshell#helpers#get_winwidth(),
          \ '$VIMSHELL' : 1,
          \ '$COLUMNS' : vimshell#helpers#get_winwidth(),
          \ '$LINES' : g:vimshell_scrollback_limit,
          \ '$VIMSHELL_TERM' : 'interactive',
          \ '$EDITOR' : vimshell#helpers#get_editor_name(),
          \ '$GIT_EDITOR' : vimshell#helpers#get_editor_name(),
          \ '$PAGER' : g:vimshell_cat_command,
          \ '$GIT_PAGER' : g:vimshell_cat_command,
          \})

    " Initialize.
    let sub = vimproc#ptyopen(commands)
  finally
    " Restore environment variables.
    call vimshell#util#restore_variables(environments_save)

    if !empty(home_save)
      " Restore $HOME.
      call vimshell#util#restore_variables(home_save)
    endif
  endtry

  " Set variables.
  let interactive = {
        \ 'type' : 'interactive',
        \ 'process' : sub,
        \ 'fd' : a:context.fd,
        \ 'encoding' : options['--encoding'],
        \ 'is_secret': 0,
        \ 'prompt_history' : {},
        \ 'is_pty' : (!vimshell#util#is_windows() || use_cygpty),
        \ 'args' : args,
        \ 'echoback_linenr' : 0,
        \ 'prompt_nr' : line('.'),
        \ 'width' : vimshell#helpers#get_winwidth(),
        \ 'height' : g:vimshell_scrollback_limit,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'command' : fnamemodify(use_cygpty ? args[1] : args[0], ':t:r'),
        \ 'cmdline' : join(args),
        \ 'is_close_immediately' :
        \   get(a:context, 'is_close_immediately', 0),
        \ 'hook_functions_table' : {},
        \}

  call vimshell#commands#iexe#init(a:context, interactive,
        \ new_pos, old_pos, 1)

  call vimshell#interactive#execute_process_out(1)

  if b:interactive.process.is_valid
    call vimshell#view#_simple_insert()
  endif
endfunction"}}}
function! s:command.complete(args) abort "{{{
  if len(a:args) == 1
    return vimshell#complete#helper#executables(a:args[-1])
  elseif vimshell#util#is_windows() &&
        \ len(a:args) > 1 && a:args[1] == 'fakecygpty'
    return vimshell#complete#helper#executables(
          \ a:args[-1], g:vimshell_interactive_cygwin_path)
  endif

  return vimshell#complete#helper#args(a:args[1], a:args[2:])
endfunction"}}}

function! vimshell#commands#iexe#define() abort
  return s:command
endfunction

" Set interactive options. "{{{
if vimshell#util#is_windows()
  " Windows only options.
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'bash,bc,gosh,python,zsh', '-i')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'irb', '--inf-ruby-mode')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'powershell', '-Command -')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'scala', '-Xnojline')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'nyaos', '-t')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'fsi', '--gui- --readline-')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'sbt',
        \  '-Djline.WindowsTerminal.directConsole=false')
  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_command_options, 'ipython,ipython3',
        \ '--TerminalInteractiveShell.readline_use=False')

  call vimshell#util#set_default_dictionary_helper(
        \ g:vimshell_interactive_cygwin_commands, 'tail,zsh,ssh', 1)
endif
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_command_options, 'termtter', '--monochrome')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_command_options, 'php', '-a')

" Set interpreter commands.
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'ruby', 'irb')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'python', 'python')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'perl', 'perlsh')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'perl6', 'perl6')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'sh', 'sh')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'zsh', 'zsh')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'bash', 'bash')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'erlang', 'erl')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'scheme', 'gosh')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'clojure', 'clj')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'lisp', 'clisp')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'ps1', 'powershell')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'haskell', 'ghci')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'dosbatch', 'cmdproxy')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'scala',
      \  vimshell#util#is_windows() ? 'scala.bat' : 'scala')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'ocaml', 'ocaml')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'sml', 'sml')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'javascript', 'js')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_interpreter_commands, 'php', 'php')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_prompts, 'termtter', '> ')
call vimshell#util#set_default_dictionary_helper(
      \ g:vimshell_interactive_monochrome_commands, 'earthquake', '1')
"}}}

function! s:default_settings() abort "{{{
  " Common.
  call vimshell#init#_default_settings()

  " Define mappings.
  call vimshell#int_mappings#define_default_mappings()
endfunction"}}}

function! s:default_syntax() abort "{{{
  " Set syntax.
  syntax match InteractiveError
      \ '!!![^!].*!!!' contains=InteractiveErrorHidden
  highlight def link InteractiveError Error

  if has('conceal')
    " Supported conceal features.
    syntax match   InteractiveErrorHidden
          \ '!!!' contained conceal
  else
    syntax match   InteractiveErrorHidden
          \ '!!!' contained
    highlight def link InteractiveErrorHidden Ignore
  endif
endfunction"}}}

function! vimshell#commands#iexe#init(context, interactive, new_pos, old_pos, is_insert) abort "{{{
  " Save current directiory.
  let cwd = getcwd()

  let loaded = s:manager.open('iexe-'.substitute(join(a:interactive.args),
        \ '[<>|]', '_', 'g') .'@'.(bufnr('$')+1), 'silent edit')
  if !loaded
    call vimshell#echo_error(
          \ '[vimshell] Failed to open Buffer.')
    return
  endif

  let [a:new_pos[2], a:new_pos[3]] = [bufnr('%'), getpos('.')]

  let b:interactive = a:interactive

  call s:default_settings()

  call vimshell#cd(cwd)

  let syntax = 'int-' . a:interactive.command
  let &filetype = syntax
  let b:interactive.syntax = syntax

  call s:default_syntax()

  " Set autocommands.
  augroup vimshell
    autocmd BufDelete,VimLeavePre <buffer>
          \ call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd BufWinEnter,WinEnter <buffer>
          \ call s:event_bufwin_enter()
  augroup END

  " Set send buffer.
  call vimshell#interactive#set_send_buffer(bufnr('%'))

  noautocmd call vimshell#helpers#restore_pos(a:old_pos)

  if get(a:context, 'is_single_command', 0)
    call vimshell#next_prompt(a:context, a:is_insert)
    noautocmd call vimshell#helpers#restore_pos(a:new_pos)
  endif
endfunction"}}}

function! s:event_bufwin_enter() abort "{{{
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
endfunction"}}}

" vim: foldmethod=marker
