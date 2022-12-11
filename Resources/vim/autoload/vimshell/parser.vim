"=============================================================================
" FILE: parser.vim
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

function! vimshell#parser#check_script(script) abort "{{{
  " Parse check only.
  " Split statements.
  for statement in vimproc#parser#split_statements(a:script)
    call vimproc#parser#split_args(vimshell#parser#parse_alias(statement))
  endfor
endfunction"}}}
function! vimshell#parser#eval_script(script, context) abort "{{{
  let context = vimshell#init#_context(a:context)

  " Split statements.
  let statements = vimproc#parser#parse_statements(a:script)
  let max = len(statements)

  let context = a:context
  let context.is_single_command = (context.is_interactive && max == 1)

  let i = 0
  while i < max
    try
      let ret =  s:execute_statement(statements[i].statement, context)
    catch /^exe: Process started./
      " Change continuation.
      let b:vimshell.continuation = {
            \ 'statements' : statements[i : ], 'context' : context,
            \ 'script' : a:script,
            \ }
      call vimshell#interactive#execute_process_out(0)
      return 1
    endtry

    let condition = statements[i].condition
    if (condition ==# 'true' && ret)
          \ || (condition ==# 'false' && !ret)
      break
    endif

    let i += 1
  endwhile

  " Call postexec hook.
  call vimshell#hook#call('postexec', context, a:script)

  return 0
endfunction"}}}
function! vimshell#parser#execute_command(commands, context) abort "{{{
  if empty(a:commands)
    return 0
  endif

  let commands = a:commands
  let program = commands[0].args[0]
  let args = commands[0].args[1:]
  let fd = {
        \ 'stdin' : commands[0].fd.stdin,
        \ 'stdout' : commands[-1].fd.stdout,
        \ 'stderr' : commands[-1].fd.stderr,
        \ }
  let context = a:context
  let context.fd = fd

  let internal_commands = vimshell#available_commands(program)

  let dir = substitute(substitute(program, '^\~\ze[/\\]',
        \ substitute($HOME, '\\', '/', 'g'), ''),
        \          '\\\(.\)', '\1', 'g')

  " Check pipeline.
  if get(get(internal_commands, program, {}),
        \ 'kind', '') ==  'execute'
    " Execute execute commands.
    let commands[0].args = args
    return vimshell#helpers#execute_internal_command(program, commands, context)
  elseif program =~ '^!'
    " Convert to internal "h" command.
    if program == '!!'
      let args = []
    else
      let args = [program[1:]] + args
    endif
    return vimshell#helpers#execute_internal_command('h', args, context)
  elseif len(a:commands) > 1
    if a:commands[-1].args[0] == 'less'
      " Execute less(Syntax sugar).
      let commands = a:commands[: -2]
      if !empty(a:commands[-1].args[1:])
        let commands[0].args =
              \ a:commands[-1].args[1:] + commands[0].args
      endif
      return vimshell#helpers#execute_internal_command('less', commands, context)
    else
      " Execute external commands.
      return vimshell#helpers#execute_internal_command('exe', commands, context)
    endif
  elseif has_key(get(internal_commands, program, {}), 'execute')
    " Internal commands.
    return vimshell#helpers#execute_internal_command(program, args, context)
  elseif !executable(dir) && isdirectory(dir)
    " Directory.
    " Change the working directory like zsh.
    " Call internal cd command.
    return vimshell#helpers#execute_internal_command('cd', [dir], context)
  else "{{{
    let ext = fnamemodify(program, ':e')

    if !empty(ext) && has_key(g:vimshell_execute_file_list, ext)
      " Suffix execution.
      let args = extend(split(g:vimshell_execute_file_list[ext]),
            \ a:commands[0].args)
      let commands = [ { 'args' : args, 'fd' : fd } ]
      return vimshell#parser#execute_command(commands, a:context)
    else
      let args = insert(args, program)

      if has_key(g:vimshell_terminal_commands, program)
            \ && g:vimshell_terminal_commands[program]
        " Execute terminal commands.
        return vimshell#helpers#execute_internal_command('iexe', commands, context)
      else
        " Execute external commands.
        return vimshell#helpers#execute_internal_command('exe', commands, context)
      endif
    endif
  endif"}}}
endfunction
"}}}
function! vimshell#parser#execute_continuation(is_insert) abort "{{{
  " Execute pipe.
  call vimshell#interactive#execute_process_out(a:is_insert)

  if empty(b:vimshell.continuation)
    return
  endif

  if b:interactive.process.is_valid
    return 1
  endif

  let b:vimshell.system_variables['status'] = b:interactive.status
  let b:interactive.encoding = &encoding
  let ret = b:interactive.status

  let statements = b:vimshell.continuation.statements
  let condition = statements[0].condition
  if (condition ==# 'true' && ret)
        \ || (condition ==# 'false' && !ret)
    " Exit.
    let b:vimshell.continuation.statements = []
    let statements = []
  endif

  if ret != 0
    " Print exit value.
    let context = b:vimshell.continuation.context
    if b:interactive.cond ==# 'signal'
      " Note: Ignore SIGINT.
      if b:interactive.status != 2
        let message = printf('vimshell: %s %d(%s) "%s"',
              \ b:interactive.cond, b:interactive.status,
              \ vimshell#interactive#decode_signal(b:interactive.status),
              \   b:interactive.cmdline)
        call vimshell#error_line(context.fd, message)
      endif
    else
      let message = printf('vimshell: %s %d "%s"',
            \ b:interactive.cond, b:interactive.status, b:interactive.cmdline)

      call vimshell#error_line(context.fd, message)
    endif
  endif

  " Execute rest commands.
  let statements = statements[1:]
  let max = len(statements)
  let context = b:vimshell.continuation.context

  let i = 0

  while i < max
    try
      let ret = s:execute_statement(statements[i].statement, context)
    catch /^exe: Process started./
      " Change continuation.
      let b:vimshell.continuation.statements = statements[i : ]
      let b:vimshell.continuation.context = context
      return 1
    endtry

    let condition = statements[i].condition
    if (condition ==# 'true' && ret)
          \ || (condition ==# 'false' && !ret)
      break
    endif

    let i += 1
  endwhile

  if !exists('b:vimshell')
    return
  endif

  " Call postexec hook.
  call vimshell#hook#call('postexec',
        \ context, b:vimshell.continuation.script)

  let b:vimshell.continuation = {}

  if b:interactive.syntax !=# &filetype
    " Set highlight.
    let start = searchpos(
          \ b:vimshell.context.prompt_pattern, 'bWn')[0]
    if start > 0
      call s:highlight_with(start + 1,
            \ printf('"\ze\%%(^\[%%\]\|%s\)"',
            \        b:vimshell.context.prompt_pattern),
            \ b:interactive.syntax)
    endif

    let b:interactive.syntax = &filetype
  endif

  call vimshell#next_prompt(context, a:is_insert)
endfunction
"}}}
function! s:execute_statement(statement, context) abort "{{{
  let statement = vimshell#parser#parse_alias(a:statement)

  " Call preexec filter.
  let statement = vimshell#hook#call_filter(
        \ 'preexec', a:context, statement)

  let program = vimshell#parser#parse_program(statement)

  let internal_commands = vimshell#available_commands(program)
  if program =~ '^\s*:'
    " Convert to vexe special command.
    let fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    let commands = [ { 'args' :
          \ split(substitute(statement, '^:', 'vexe ', '')), 'fd' : fd } ]
  elseif statement =~ '&$'
    " Convert to internal "bg" command.
    let commands = vimproc#parser#parse_pipe(statement)
    let commands[-1].args[-1] = commands[-1].args[-1][:-2]
    if commands[-1].args[-1] == ''
      " Delete empty arg.
      call remove(commands[-1].args, -1)
    endif

    call insert(commands[-1].args, 'bg')
  elseif has_key(internal_commands, program)
        \ && internal_commands[program].kind ==# 'special'
    " Special commands.
    let fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
    let commands = [ { 'args' : split(statement), 'fd' : fd } ]
  else
    let commands = vimproc#parser#parse_pipe(statement)
  endif

  return vimshell#parser#execute_command(commands, a:context)
endfunction
"}}}

" Parse helper.
function! vimshell#parser#parse_alias(statement) abort "{{{
  let statement = s:parse_galias(a:statement)
  let program = matchstr(statement, vimshell#helpers#get_program_pattern())
  if statement != '' && program  == ''
    throw 'Error: Invalid command name.'
  endif

  if exists('b:vimshell') &&
        \ !empty(get(b:vimshell.alias_table, program, []))
    " Expand alias.
    let args = vimproc#parser#split_args_through(
          \ statement[matchend(statement, vimshell#helpers#get_program_pattern()) :])
    let statement = s:recursive_expand_alias(program, args)
  endif

  return statement
endfunction"}}}
function! vimshell#parser#parse_program(statement) abort "{{{
  " Get program.
  let program = matchstr(a:statement, vimshell#helpers#get_program_pattern())
  if program  == ''
    throw 'Error: Invalid command name.'
  endif

  if program != '' && program[0] == '~'
    " Parse tilde.
    let program =
          \ vimshell#util#substitute_path_separator($HOME)
          \ . program[1:]
  endif

  return program
endfunction"}}}
function! s:parse_galias(script) abort "{{{
  if !exists('b:vimshell')
    return a:script
  endif

  let script = a:script
  let max = len(script)
  let args = []
  let arg = ''
  let i = 0
  while i < max
    if script[i] == '\'
      " Escape.
      let i += 1

      if i >= max
        throw 'Exception: Join to next line (\).'
      endif

      let arg .= '\' .  script[i]
      let i += 1
    elseif script[i] != ' '
      let arg .= script[i]
      let i += 1
    else
      " Space.
      if arg != ''
        call add(args, arg)
      endif

      let arg = ''

      let i += 1
    endif
  endwhile

  if arg != ''
    call add(args, arg)
  endif

  " Expand global alias.
  let i = 0
  for arg in args
    if has_key(b:vimshell.galias_table, arg)
      let args[i] = b:vimshell.galias_table[arg]
    endif

    let i += 1
  endfor

  return join(args)
endfunction"}}}
function! s:recursive_expand_alias(alias_name, args) abort "{{{
  " Recursive expand alias.
  let alias = b:vimshell.alias_table[a:alias_name]
  let expanded = {}
  while 1
    if has_key(expanded, alias) || !has_key(b:vimshell.alias_table, alias)
      break
    endif

    let expanded[alias] = 1
    let alias = b:vimshell.alias_table[alias]
  endwhile

  " Expand variables.
  let script = ''

  let i = 0
  let max = len(alias)
  let args = insert(copy(a:args), a:alias_name)
  try
    while i < max
      let matchlist = matchlist(alias,
            \'^$$args\(\[\d\+\%(:\%(\d\+\)\?\)\?\]\)\?', i)
      if empty(matchlist)
        let script .= alias[i]
        let i += 1
      else
        let index = matchlist[1]

        if index == ''
          " All args.
          let script .= join(args[1:])
        elseif index =~ '^\[\d\+\]$'
          let script .= get(args, index[1: -2], '')
        else
          " Some args.
          let script .= join(eval('args' . index))
        endif

        let i += len(matchlist[0])
      endif
    endwhile
  endtry

  if script ==# alias && !empty(a:args)
    let script .= ' ' . join(a:args)
  endif

  return script
endfunction"}}}

" Misc.
function! vimshell#parser#check_wildcard() abort "{{{
  let args = vimshell#helpers#get_current_args()
  return !empty(args) && args[-1] =~ '[[*?]\|^\\[()|]'
endfunction"}}}
function! vimshell#parser#getopt(args, optsyntax, ...) abort "{{{
  let default_values = get(a:000, 0, {})

  " Initialize.
  let optsyntax = a:optsyntax
  if !has_key(optsyntax, 'noarg')
    let optsyntax['noarg'] = []
  endif
  if !has_key(optsyntax, 'noarg_short')
    let optsyntax['noarg_short'] = []
  endif
  if !has_key(optsyntax, 'arg1')
    let optsyntax['arg1'] = []
  endif
  if !has_key(optsyntax, 'arg1_short')
    let optsyntax['arg1_short'] = []
  endif
  if !has_key(optsyntax, 'arg=')
    let optsyntax['arg='] = []
  endif

  let args = []
  let options = {}
  for arg in a:args
    let found = 0

    for opt in optsyntax['noarg']
      if arg ==# opt
        let found = 1

        " Get argument value.
        let options[opt] = 1

        break
      endif
    endfor

    for opt in optsyntax['arg=']
      if vimshell#util#head_match(arg, opt.'=')
        let found = 1

        " Get argument value.
        let options[opt] = arg[len(opt.'='):]

        break
      endif
    endfor

    if !found
      call add(args, arg)
    endif
  endfor

  " Set default value.
  for [opt, default] in items(default_values)
    if !has_key(options, opt)
      let options[opt] = default
    endif
  endfor

  return [args, options]
endfunction"}}}
function! s:highlight_with(start, end, syntax) abort "{{{
  let cnt = get(b:, 'highlight_count', 0)
  if globpath(&runtimepath, 'syntax/' . a:syntax . '.vim') == ''
    return
  endif
  unlet! b:current_syntax
  let save_isk= &l:iskeyword  " For scheme.
  execute printf('silent! syntax include @highlightWith%d syntax/%s.vim',
        \              cnt, a:syntax)
  let &l:iskeyword = save_isk
  execute printf('syntax region highlightWith%d start=/\%%%dl/ end=%s keepend '
        \            . 'contains=@highlightWith%d,VimShellError',
        \             cnt, a:start, a:end, cnt)
  let b:highlight_count = cnt + 1
endfunction"}}}

" vim: foldmethod=marker
