"=============================================================================
" FILE: init.vim
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

" Global options definition. "{{{
let g:vimshell_enable_start_insert =
      \ get(g:, 'vimshell_enable_start_insert', 1)
"}}}

let s:manager = vimshell#util#get_vital().import('Vim.Buffer')

function! vimshell#init#_start(path, ...) abort "{{{
  " Check vimproc. "{{{
  if !vimshell#util#has_vimproc()
    call vimshell#echo_error(v:errmsg)
    call vimshell#echo_error(v:exception)
    call vimshell#echo_error('Error occurred while loading vimproc.')
    call vimshell#echo_error('Please install vimproc Ver.6.0 or above.')
    return
  elseif vimproc#version() < 600
    call vimshell#echo_error('Your vimproc is too old.')
    call vimshell#echo_error('Please install vimproc Ver.6.0 or above.')
    return
  endif"}}}

  if vimshell#util#is_cmdwin()
    call vimshell#echo_error(
          \ '[vimshell] Command line buffer is detected!')
    call vimshell#echo_error(
          \ '[vimshell] Please close command line buffer.')
    return
  endif

  " Detect autochdir option. "{{{
  if exists('+autochdir') && &autochdir
    call vimshell#echo_error(
          \ '[vimshell] Detected autochdir!')
    call vimshell#echo_error(
          \ '[vimshell] vimshell does''t work if you set autochdir option.')
    return
  endif
  "}}}

  let path = a:path
  if path != ''
    let path = vimshell#util#substitute_path_separator(
          \ fnamemodify(vimshell#util#expand(a:path), ':p'))

    if !isdirectory(path)
      call vimshell#echo_error(
            \ printf('[vimshell] argument path: "%s" invalid!', path))
      " Don't use argument path.
      let path = ''
    endif
  endif

  let context = vimshell#init#_context(get(a:000, 0, {}))

  if context.create
    " Create shell buffer.
    call s:create_shell(path, context)
    return
  elseif context.toggle
        \ && vimshell#view#_close(context.buffer_name)
    return
  elseif &filetype ==# 'vimshell'
    " Search vimshell buffer.
    call s:switch_vimshell(bufnr('%'), context, path)
    return
  endif

  if !exists('t:vimshell')
    call vimshell#init#tab_variable()
  endif
  for bufnr in filter(insert(range(1, bufnr('$')),
        \ t:vimshell.last_vimshell_bufnr),
        \ "buflisted(v:val) &&
        \  getbufvar(v:val, '&filetype') ==# 'vimshell'")
    if (!exists('t:tabpagebuffer')
          \    || has_key(t:tabpagebuffer, bufnr))
      call s:switch_vimshell(bufnr, context, path)
      return
    endif
  endfor

  " Create shell buffer.
  call s:create_shell(path, context)
endfunction"}}}

function! vimshell#init#_context(context) abort "{{{
  let default_context = {
    \ 'buffer_name' : 'default',
    \ 'quit' : 0,
    \ 'toggle' : 0,
    \ 'create' : 0,
    \ 'simple' : 0,
    \ 'split' : 0,
    \ 'popup' : 0,
    \ 'winwidth' : 0,
    \ 'winminwidth' : 0,
    \ 'project' : 0,
    \ 'tab' : 0,
    \ 'direction' : '',
    \ 'prompt' : get(g:,
    \      'vimshell_prompt', 'vimshell% '),
    \ 'prompt_expr' : get(g:,
    \      'vimshell_prompt_expr', ''),
    \ 'prompt_pattern' : get(g:,
    \      'vimshell_prompt_pattern', ''),
    \ 'secondary_prompt' : get(g:,
    \      'vimshell_secondary_prompt', '%% '),
    \ 'user_prompt' : get(g:,
    \      'vimshell_user_prompt', ''),
    \ 'right_prompt' : get(g:,
    \      'vimshell_right_prompt', ''),
    \ }
  let context = extend(default_context, a:context)

  " Complex initializer.
  if !has_key(context, 'profile_name')
    let context.profile_name = context.buffer_name
  endif
  if !has_key(context, 'split_command')
    if context.popup && g:vimshell_popup_command == ''
      " Default popup command.
      let context.split_command = 'split | resize '
            \ . winheight(0)*g:vimshell_popup_height/100
    elseif context.popup
      let context.split_command = g:vimshell_popup_command
    elseif context.split
      let context.split_command = g:vimshell_split_command
    else
      let context.split_command = ''
    endif
  endif

  " Set prompt pattern.
  if context.prompt_pattern == ''
    if context.prompt_expr != ''
      " Error.
      call vimshell#echo_error(
            \ 'Your prompt_pattern is invalid. '.
            \ 'You must set prompt_pattern in vimshell.')
    endif

    let context.prompt_pattern =
          \ '^' . vimshell#util#escape_match(context.prompt)
  endif

  if &l:modified && !&l:hidden
    " Split automatically.
    let context.split = 1
  endif

  " Initialize.
  let context.has_head_spaces = 0
  let context.is_interactive = 1
  let context.is_insert = 1
  let context.fd = { 'stdin' : '', 'stdout': '', 'stderr': ''}

  return context
endfunction"}}}

function! vimshell#init#_internal_commands(command) abort "{{{
  " Initialize internal commands table.
  let internal_commands = vimshell#variables#internal_commands()

  if has_key(internal_commands, a:command) || a:command =~ '\.'
    return get(internal_commands, a:command, {})
  endif

  " Search autoload.
  for list in split(globpath(&runtimepath,
        \ 'autoload/vimshell/commands/' . a:command . '*.vim'), '\n')
    let command_name = fnamemodify(list, ':t:r')
    if command_name == '' ||
          \ has_key(internal_commands, command_name)
      continue
    endif

    let result = {'vimshell#commands#'.command_name.'#define'}()

    for command in (type(result) == type([])) ?
          \ result : [result]
      if !has_key(command, 'description')
        let command.description = ''
      endif

      let internal_commands[command.name] = command
    endfor

    unlet result
  endfor

  return get(internal_commands, a:command, {})
endfunction"}}}

function! vimshell#init#_default_settings() abort "{{{
  " Common.
  setlocal bufhidden=hide
  setlocal buftype=nofile
  setlocal nolist
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  setlocal winfixheight
  setlocal noreadonly
  setlocal iskeyword+=-,+,\\,!,~
  setlocal textwidth=0
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=nvi
  endif
  if exists('&colorcolumn')
    setlocal colorcolumn=
  endif
endfunction"}}}

function! vimshell#init#tab_variable() abort "{{{
  let t:vimshell = {
        \ 'last_vimshell_bufnr' : -1,
        \ 'last_interactive_bufnr' : -1,
        \ }
endfunction"}}}

function! s:create_shell(path, context) abort "{{{
  let path = a:path
  if path == ''
    " Use current directory.
    let path = vimshell#util#substitute_path_separator(getcwd())
  endif

  if a:context.project
    let path = vimshell#util#path2project_directory(path)
  endif

  " Create new buffer.
  let prefix = '[vimshell] - '
  let prefix .= a:context.profile_name
  let postfix = s:get_postfix(prefix, 1)
  let bufname = prefix . postfix

  if a:context.split_command != ''
    call vimshell#helpers#split(a:context.split_command)
  endif

  " Save swapfile option.
  let swapfile_save = &swapfile
  set noswapfile

  try
    let loaded = s:manager.open(bufname, 'silent edit')
  finally
    let &swapfile = swapfile_save
  endtry

  if !loaded
    call vimshell#echo_error(
          \ '[vimshell] Failed to open Buffer.')
    return
  endif

  call s:initialize_vimshell(path, a:context)
  call vimshell#interactive#set_send_buffer(bufname('%'))

  call vimshell#print_prompt(a:context)

  if g:vimshell_enable_start_insert
    call vimshell#start_insert()
  endif

  " Check prompt value. "{{{
  let prompt = vimshell#get_prompt()
  if vimshell#util#head_match(prompt, vimshell#get_secondary_prompt())
        \ || vimshell#util#head_match(vimshell#get_secondary_prompt(), prompt)
    call vimshell#echo_error(printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ prompt, vimshell#get_secondary_prompt()))
    finish
  elseif vimshell#util#head_match(prompt, '[%] ')
        \ || vimshell#util#head_match('[%] ', prompt)
    call vimshell#echo_error(printf('Head matched g:vimshell_prompt("%s")'.
          \ ' and your g:vimshell_user_prompt("[%] ").', prompt))
    finish
  elseif vimshell#util#head_match('[%] ', vimshell#get_secondary_prompt())
        \ || vimshell#util#head_match(vimshell#get_secondary_prompt(), '[%] ')
    call vimshell#echo_error(printf('Head matched g:vimshell_user_prompt("[%] ")'.
          \ ' and your g:vimshell_secondary_prompt("%s").',
          \ vimshell#get_secondary_prompt()))
    finish
  endif"}}}
endfunction"}}}

function! s:switch_vimshell(bufnr, context, path) abort "{{{
  if bufwinnr(a:bufnr) > 0
    execute bufwinnr(a:bufnr) 'wincmd w'
  else
    if a:context.split_command != ''
      call vimshell#helpers#split(a:context.split_command)
    endif

    execute 'buffer' a:bufnr
  endif

  if !empty(b:vimshell.continuation)
    return
  endif

  if a:path != '' && isdirectory(a:path)
    " Change current directory.
    let current = fnamemodify(a:path, ':p')
    let b:vimshell.current_dir = current
    call vimshell#cd(current)
  endif

  if getline('$') =~# a:context.prompt_pattern.'$'
    " Delete current prompt.
    let promptnr = vimshell#view#_check_user_prompt(line('$')) > 0 ?
          \ vimshell#view#_check_user_prompt(line('$')) . ',' : ''
    silent execute promptnr . '$delete _'
  endif

  normal! zb

  call vimshell#print_prompt()
  if g:vimshell_enable_start_insert
    call vimshell#start_insert()
  endif
endfunction"}}}

function! s:initialize_vimshell(path, context) abort "{{{
  " Load history.
  let g:vimshell#hist_buffer = vimshell#history#read()

  " Initialize variables.
  let b:vimshell = {}

  let b:vimshell.current_dir = a:path
  let b:vimshell.alias_table = {}
  let b:vimshell.galias_table = {}
  let b:vimshell.altercmd_table = {}
  let b:vimshell.commandline_stack = []
  let b:vimshell.variables = {}
  let b:vimshell.system_variables = { 'status' : 0 }
  let b:vimshell.directory_stack = []
  let b:vimshell.prompt_current_dir = {}
  let b:vimshell.continuation = {}
  let b:vimshell.prompts_save = {}
  let b:vimshell.statusline =
        \ '*vimshell* : %{vimshell#get_status_string()}' .
        \ "\ %=%{exists('b:vimshell') ? printf('%s %4d/%d',
        \  b:vimshell.right_prompt, line('.'), line('$')) : ''}"
  let b:vimshell.right_prompt = ''

  " Default settings.
  call s:default_settings()

  " Change current directory.
  call vimshell#cd(a:path)

  call vimshell#set_context(a:context)

  " Set interactive variables.
  let b:interactive = {
        \ 'type' : 'vimshell',
        \ 'syntax' : 'vimshell',
        \ 'process' : {},
        \ 'continuation' : {},
        \ 'fd' : a:context.fd,
        \ 'encoding' : &encoding,
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'width' : vimshell#helpers#get_winwidth(),
        \ 'height' : g:vimshell_scrollback_limit,
        \ 'hook_functions_table' : {},
        \}

  " Load rc file.
  if filereadable(g:vimshell_vimshrc_path)
    call vimshell#helpers#execute_internal_command('vimsh',
          \ [g:vimshell_vimshrc_path],
          \ { 'has_head_spaces' : 0, 'is_interactive' : 0 })
    let b:vimshell.loaded_vimshrc = 1
  endif

  setfiletype vimshell

  call vimshell#help#init()
  call vimshell#interactive#init()

  call vimshell#handlers#_restore_statusline()
endfunction"}}}

function! s:default_settings() abort "{{{
  " Common.
  call vimshell#init#_default_settings()

  " Set autocommands.
  augroup vimshell
    autocmd BufDelete,VimLeavePre <buffer>
          \ call vimshell#interactive#hang_up(expand('<afile>'))
    autocmd BufEnter,BufWinEnter,WinEnter,BufRead <buffer>
          \ call vimshell#handlers#_on_bufwin_enter(expand('<abuf>'))
  augroup end

  call vimshell#handlers#_on_bufwin_enter(bufnr('%'))

  " Define mappings.
  call vimshell#mappings#define_default_mappings()
endfunction"}}}
function! s:get_postfix(prefix, is_create) abort "{{{
  let buffers = get(a:000, 0, range(1, bufnr('$')))
  let buflist = vimshell#util#sort_by(filter(map(buffers,
        \ 'bufname(v:val)'), 'stridx(v:val, a:prefix) >= 0'),
        \ "str2nr(matchstr(v:val, '\\d\\+$'))")
  if empty(buflist)
    return ''
  endif

  let num = matchstr(buflist[-1], '@\zs\d\+$')
  return num == '' && !a:is_create ? '' :
        \ '@' . (a:is_create ? (num + 1) : num)
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
