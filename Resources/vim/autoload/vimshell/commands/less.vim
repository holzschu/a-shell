"=============================================================================
" FILE: less.vim
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
      \ 'name' : 'less',
      \ 'kind' : 'execute',
      \ 'description' : 'less [{option}...] {command}',
      \}
function! s:command.execute(commands, context) abort "{{{
  " Execute command in background.
  if empty(a:commands)
    return
  endif

  let commands = a:commands
  let [commands[0].args, options] = vimshell#parser#getopt(commands[0].args, {
        \ 'arg=' : ['--encoding', '--syntax', '--split'],
        \ }, {
        \ '--encoding' : vimshell#interactive#get_default_encoding(a:commands),
        \ '--syntax' : 'vimshell-less',
        \ '--split' : g:vimshell_split_command,
        \ })

  if empty(commands[0].args)
    return
  endif

  if !executable(commands[0].args[0])
    return vimshell#helpers#execute_internal_command(
          \ 'view', commands[0].args, a:context)
  endif

  " Background execute.
  if exists('b:interactive') && get(b:interactive.process, 'is_valid')
    " Delete zombie process.
    call vimshell#interactive#force_exit()
  endif

  " Encoding conversion.
  if options['--encoding'] != '' && options['--encoding'] != &encoding
    for command in commands
      call map(command.args,
            \ 'vimproc#util#iconv(v:val, &encoding, options["--encoding"])')
    endfor
  endif

  " Set variables.
  let interactive = {
        \ 'type' : 'less',
        \ 'syntax' : options['--syntax'],
        \ 'fd' : a:context.fd,
        \ 'encoding' : options['--encoding'],
        \ 'is_pty' : 0,
        \ 'echoback_linenr' : 0,
        \ 'command' : commands[0].args[0],
        \ 'cmdline' : join(commands[0].args),
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \ 'width' : vimshell#helpers#get_winwidth(),
        \ 'height' : g:vimshell_scrollback_limit,
        \}

  return s:init(a:commands, a:context, options, interactive)
endfunction"}}}
function! s:command.complete(args) abort "{{{
  return vimshell#complete#helper#command_args(a:args)
endfunction"}}}

function! vimshell#commands#less#define() abort
  return s:command
endfunction

function! s:init(commands, context, options, interactive) abort "{{{
  " Save current directiory.
  let cwd = getcwd()

  let [new_pos, old_pos] = vimshell#helpers#split(a:options['--split'])

  " Set environment variables.
  let environments_save = vimshell#util#set_variables({
        \ '$TERM' : g:vimshell_environment_term,
        \ '$TERMCAP' : 'COLUMNS=' . vimshell#helpers#get_winwidth(),
        \ '$VIMSHELL' : 1,
        \ '$COLUMNS' : vimshell#helpers#get_winwidth(),
        \ '$LINES' : g:vimshell_scrollback_limit,
        \ '$VIMSHELL_TERM' : 'less',
        \ '$EDITOR' : vimshell#helpers#get_editor_name(),
        \ '$GIT_EDITOR' : vimshell#helpers#get_editor_name(),
        \ '$PAGER' : g:vimshell_cat_command,
        \ '$GIT_PAGER' : g:vimshell_cat_command,
        \})

  " Initialize.
  let a:interactive.process = vimproc#plineopen2(a:commands)

  " Restore environment variables.
  call vimshell#util#restore_variables(environments_save)

  " Input from stdin.
  if a:interactive.fd.stdin != ''
    call a:interactive.process.stdin.write(
          \ vimshell#interactive#read(a:context.fd))
  endif
  call a:interactive.process.stdin.close()

  let a:interactive.width = vimshell#helpers#get_winwidth()
  let a:interactive.height = g:vimshell_scrollback_limit

  let args = ''
  for command in a:commands
    let args .= join(command.args)
  endfor

  let loaded = s:manager.open('less-'.substitute(args,
        \ '[<>|]', '_', 'g') .'@'.(bufnr('$')+1), 'silent edit')
  if !loaded
    call vimshell#echo_error(
          \ '[vimshell] Failed to open Buffer.')
    return
  endif

  let [new_pos[2], new_pos[3]] = [bufnr('%'), getpos('.')]

  " Common.
  setlocal nolist
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal tabstop=8
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=n
  endif

  " For less.
  setlocal nomodifiable

  setlocal filetype=vimshell-less
  let &syntax = a:options['--syntax']
  let b:interactive = a:interactive

  call vimshell#cd(cwd)

  " Set syntax.
  syn region   InteractiveError
        \ start=+!!!+ end=+!!!+ contains=InteractiveErrorHidden oneline
  if v:version >= 703
    " Supported conceal features.
    syn match   InteractiveErrorHidden  '!!!' contained conceal
  else
    syn match   InteractiveErrorHidden  '!!!' contained
  endif
  hi def link InteractiveErrorHidden Error

  augroup vimshell
    autocmd BufDelete,VimLeavePre <buffer>
          \ call vimshell#interactive#hang_up(expand('<afile>'))
  augroup END

  nnoremap <buffer><silent> <Plug>(vimshell_less_execute_line)
        \ :<C-u>call <SID>on_execute()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_interrupt)
        \ :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_exit)
        \ :<C-u>call vimshell#interactive#quit_buffer()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_line)
        \ :<C-u>call <SID>next_line()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_screen)
        \ :<C-u>call <SID>next_screen()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_next_half_screen)
        \ :<C-u>call <SID>next_half_screen()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_less_last_screen)
        \ :<C-u>call <SID>last_screen()<CR>

  nmap <buffer><CR>      <Plug>(vimshell_less_execute_line)
  nmap <buffer><C-c>     <Plug>(vimshell_less_interrupt)
  nmap <buffer>q         <Plug>(vimshell_less_exit)
  nmap <buffer>j         <Plug>(vimshell_less_next_line)
  nmap <buffer>f         <Plug>(vimshell_less_next_screen)
  nmap <buffer><C-f>     <Plug>(vimshell_less_next_screen)
  nmap <buffer>d         <Plug>(vimshell_less_next_half_screen)
  nmap <buffer><C-d>     <Plug>(vimshell_less_next_half_screen)
  nmap <buffer>G     <Plug>(vimshell_less_last_screen)
  nmap <buffer><Space>   <Plug>(vimshell_less_next_screen)
  nnoremap <buffer>b     <C-b>
  nnoremap <buffer>u     <C-u>

  call s:print_output(winheight(0))

  noautocmd call vimshell#helpers#restore_pos(old_pos)

  if get(a:context, 'is_single_command', 0)
    call vimshell#next_prompt(a:context, 0)
    noautocmd call vimshell#helpers#restore_pos(new_pos)
    stopinsert
  endif
endfunction"}}}

function! s:next_line() abort "{{{
  if line('.') == line('$')
    call s:print_output(2)
  endif

  call cursor(line('.')+1, 0)
endfunction "}}}
function! s:next_screen() abort "{{{
  if line('.') == line('$')
    call s:print_output(winheight(0))
  else
    execute "normal! \<C-f>"
  endif
endfunction "}}}
function! s:next_half_screen() abort "{{{
  if line('.') == line('$')
    call s:print_output(winheight(0)/2)
  else
    execute "normal! \<C-d>"
  endif
endfunction "}}}
function! s:last_screen() abort "{{{
  call s:print_output(-1)
endfunction "}}}

function! s:print_output(line_num) abort "{{{
  setlocal modifiable

  call cursor(line('$'), 0)
  call cursor(0, col('$'))

  if b:interactive.stdout_cache == ''
    if b:interactive.process.stdout.eof
      call vimshell#interactive#exit()
    endif

    if !b:interactive.process.is_valid
      setlocal nomodifiable
      return
    endif
  endif

  " Check cache.
  let cnt = len(split(b:interactive.stdout_cache, '\n', 1))
  if !b:interactive.process.stdout.eof
        \ && (a:line_num < 0 || cnt < a:line_num)
    echo 'Running command.'

    while !b:interactive.process.stdout.eof
        \ && (a:line_num < 0 || cnt < a:line_num)
      let b:interactive.stdout_cache .=
            \ b:interactive.process.stdout.read(100, 40)

      if a:line_num >= 0
        let cnt = len(split(b:interactive.stdout_cache, '\n', 1))
      endif
    endwhile

    redraw
    echo ''
  endif

  let match = -1
  if a:line_num >= 0
    if cnt > a:line_num
      let cnt = a:line_num
    endif

    let match = match(b:interactive.stdout_cache, '\n', 0, cnt)
  endif

  if a:line_num < 0 || match <= 0
    let output = b:interactive.stdout_cache
    let b:interactive.stdout_cache = ''
  else
    let output = b:interactive.stdout_cache[: match-1]
    let b:interactive.stdout_cache = b:interactive.stdout_cache[match :]
  endif

  call vimshell#interactive#print_buffer(b:interactive.fd, output)
  setlocal nomodifiable

  if b:interactive.stdout_cache == ''
        \ && b:interactive.process.stdout.eof
    call vimshell#interactive#exit()
  endif
endfunction"}}}
