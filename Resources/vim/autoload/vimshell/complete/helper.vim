"=============================================================================
" FILE: helper.vim
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

function! vimshell#complete#helper#files(cur_keyword_str, ...) abort "{{{
  " vimshell#complete#helper#files(cur_keyword_str [, path])

  if a:0 > 1
    call vimshell#echo_error('Too many arguments.')
  endif

  let path = (a:0 == 1 ? a:1 : '.')
  let list = vimshell#complete#helper#get_files(path, a:cur_keyword_str)

  " Extend pseudo files.
  if a:cur_keyword_str =~ '^/dev/'
    for word in vimshell#complete#helper#keyword_simple_filter(
          \  ['/dev/null', '/dev/clip', '/dev/quickfix'],
          \ a:cur_keyword_str)
      let dict = {
            \ 'word' : word, 'menu' : 'file'
            \}

      " Escape word.
      let dict.orig = vimshell#util#expand(dict.word)
      let dict.word = escape(dict.word, ' *?[]"={}')

      call add(list, dict)
    endfor
  endif

  return list
endfunction"}}}
function! vimshell#complete#helper#directories(cur_keyword_str) abort "{{{
  let ret = []
  for keyword in filter(vimshell#complete#helper#files(a:cur_keyword_str),
        \ 'isdirectory(v:val.orig) ||
        \  (vimshell#util#is_windows() && fnamemodify(v:val.orig, ":e") ==? "LNK"
        \    && isdirectory(resolve(v:val.orig)))')
    let dict = keyword
    let dict.menu = 'directory'

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#cdpath_directories(cur_keyword_str) abort "{{{
  " Check dup.
  let check = {}
  for keyword in filter(vimshell#complete#helper#files(a:cur_keyword_str, &cdpath),
        \ 'isdirectory(v:val.orig) || (vimshell#util#is_windows()
        \     && fnamemodify(v:val.orig, ":e") ==? "LNK"
        \     && isdirectory(resolve(v:val.orig)))')
    if !has_key(check, keyword.word) && keyword.word =~ '/'
      let check[keyword.word] = keyword
    endif
  endfor

  let ret = []
  for keyword in values(check)
    let dict = keyword
    let dict.menu = 'cdpath'

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#directory_stack(cur_keyword_str) abort "{{{
  if !exists('b:vimshell')
    return []
  endif

  let ret = []

  for keyword in vimshell#complete#helper#keyword_simple_filter(
        \ range(len(b:vimshell.directory_stack)), a:cur_keyword_str)
    let dict = { 'word' : keyword, 'menu' : b:vimshell.directory_stack[keyword] }

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#aliases(cur_keyword_str) abort "{{{
  if !exists('b:vimshell')
    return []
  endif

  let ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(
        \ keys(b:vimshell.alias_table), a:cur_keyword_str)
    let dict = { 'word' : keyword }

    if len(b:vimshell.alias_table[keyword]) > 15
      let dict.menu = 'alias ' .
            \ printf("%s..%s",
            \   b:vimshell.alias_table[keyword][:8],
            \   b:vimshell.alias_table[keyword][-4:])
    else
      let dict.menu = 'alias ' .
            \ b:vimshell.alias_table[keyword]
    endif

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#internals(cur_keyword_str) abort "{{{
  let commands = vimshell#available_commands(a:cur_keyword_str)
  let ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(
        \ keys(commands), a:cur_keyword_str)
    let dict = { 'word' : keyword, 'menu' : commands[keyword].kind }
    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#executables(cur_keyword_str, ...) abort "{{{
  if a:cur_keyword_str =~ '[/\\]'
    let files = vimshell#complete#helper#files(a:cur_keyword_str)
  else
    let path = a:0 > 1 ? a:1 :
          \ vimshell#util#is_windows() ? substitute($PATH, '\\\?;', ',', 'g') :
          \ substitute($PATH, '/\?:', ',', 'g')
    let files = vimshell#complete#helper#files(a:cur_keyword_str, path)
  endif

  if vimshell#util#is_windows()
    let exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')
    let pattern = (a:cur_keyword_str =~ '[/\\]')?
          \ 'isdirectory(v:val.orig) || "." .
          \  fnamemodify(v:val.orig, ":e") =~? '.string(exts) :
          \ '"." . fnamemodify(v:val.orig, ":e") =~? '.string(exts)
  else
    let pattern = (a:cur_keyword_str =~ '[/\\]')?
          \ 'isdirectory(v:val.orig) || executable(v:val.orig)'
          \ : 'executable(v:val.orig)'
  endif

  call filter(files, pattern)

  let ret = []
  for keyword in files
    let dict = keyword
    let dict.menu = 'command'
    if a:cur_keyword_str !~ '[/\\]'
      let dict.word = fnamemodify(keyword.word, ':t')
      let dict.abbr = fnamemodify(keyword.abbr, ':t')
    endif

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#buffers(cur_keyword_str) abort "{{{
  let ret = []
  let bufnumber = 1
  while bufnumber <= bufnr('$')
    if buflisted(bufnumber) &&
          \ vimshell#util#head_match(bufname(bufnumber), a:cur_keyword_str)
      let keyword = bufname(bufnumber)
      let dict = { 'word' : escape(keyword, ' *?[]"={}'), 'menu' : 'buffer' }
      call add(ret, dict)
    endif

    let bufnumber += 1
  endwhile

  return ret
endfunction"}}}
function! vimshell#complete#helper#args(command, args) abort "{{{
  let commands = vimshell#available_commands(a:command)

  " Get complete words.
  if has_key(get(commands, a:command, {}), 'complete')
    let complete_words = commands[a:command].complete(a:args)
  elseif empty(a:args)
    return []
  else
    let complete_words = vimshell#complete#helper#files(a:args[-1])
  endif

  if a:args[-1] =~ '^--\?[[:alnum:]._-]\+=\f\+$\|[<>]\+\f\+$'
    " Complete file.
    let prefix = matchstr(a:args[-1],
          \'^--[[:alnum:]._-]\+=\|^[<>]\+')
    let complete_words += vimshell#complete#helper#files(
          \ a:args[-1][len(prefix): ])
  endif

  return complete_words
endfunction"}}}
function! vimshell#complete#helper#command_args(args) abort "{{{
  " command args...
  if len(a:args) == 1
    " Commands.
    return vimshell#complete#helper#executables(a:args[0])
  else
    " Args.
    return vimshell#complete#helper#args(a:args[0], a:args[1:])
  endif
endfunction"}}}
function! vimshell#complete#helper#variables(cur_keyword_str) abort "{{{
  let _ = []

  let _ += map(copy(vimshell#complete#helper#environments(
        \ a:cur_keyword_str[1:])), "'$' . v:val")

  if a:cur_keyword_str =~ '^$\l'
    let _ += map(keys(b:vimshell.variables), "'$' . v:val")
  elseif a:cur_keyword_str =~ '^$$'
    let _ += map(keys(b:vimshell.system_variables), "'$$' . v:val")
  endif

  return vimshell#complete#helper#keyword_simple_filter(_, a:cur_keyword_str)
endfunction"}}}
function! vimshell#complete#helper#environments(cur_keyword_str) abort "{{{
  if !exists('s:envlist')
    " Get environment variables list.
    let s:envlist = map(split(system('set'), '\n'),
          \ "toupper(matchstr(v:val, '^\\h\\w*'))")
  endif

  return vimshell#complete#helper#keyword_simple_filter(
        \ copy(s:envlist), a:cur_keyword_str)
endfunction"}}}

function! vimshell#complete#helper#call_omnifunc(omnifunc) abort "{{{
  " Set complete function.
  let &l:omnifunc = a:omnifunc

  return "\<C-x>\<C-o>\<C-p>"
endfunction"}}}
function! vimshell#complete#helper#restore_omnifunc(omnifunc) abort "{{{
  if &l:omnifunc !=# a:omnifunc
    let &l:omnifunc = a:omnifunc
  endif
endfunction"}}}
function! vimshell#complete#helper#compare_rank(i1, i2) abort "{{{
  return a:i1.rank < a:i2.rank ? 1 : a:i1.rank == a:i2.rank ? 0 : -1
endfunction"}}}
function! vimshell#complete#helper#keyword_filter(list, cur_keyword_str) abort "{{{
  let cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')
  if &ignorecase
    let expr = printf('stridx(tolower(v:val.word), %s) == 0',
          \ string(tolower(cur_keyword)))
  else
    let expr = printf('stridx(v:val.word, %s) == 0',
          \ string(cur_keyword))
  endif

  return filter(a:list, expr)
endfunction"}}}
function! vimshell#complete#helper#keyword_simple_filter(list, cur_keyword_str) abort "{{{
  let cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')
  let expr = &ignorecase ?
        \ printf('stridx(tolower(v:val), %s) == 0',
        \          string(tolower(cur_keyword))) :
        \ printf('stridx(v:val, %s) == 0',
        \          string(cur_keyword))

  return filter(a:list, expr)
endfunction"}}}

function! vimshell#complete#helper#get_files(path, complete_str) abort "{{{
  let candidates = s:get_glob_files(a:path, a:complete_str)
  if a:path == ''
    let candidates = vimshell#complete#helper#keyword_filter(
          \ candidates, a:complete_str)
  endif
  return  sort(filter(copy(candidates),
        \   'v:val.action__is_directory')) +
        \ sort(filter(copy(candidates),
        \   '!v:val.action__is_directory'))
endfunction"}}}

function! s:get_glob_files(path, complete_str) abort "{{{
  let path = ',,' . substitute(a:path, '\.\%(,\|$\)\|,,', '', 'g')

  let complete_str = vimshell#util#substitute_path_separator(
        \ substitute(a:complete_str, '\\\(.\)', '\1', 'g'))

  let glob = (complete_str !~ '\*$')?
        \ complete_str . '*' : complete_str

  if a:path == ''
    let files = vimshell#util#glob(glob)
  else
    try
      let globs = globpath(path, glob)
    catch
      return []
    endtry
    let files = split(vimshell#util#substitute_path_separator(globs), '\n')
  endif

  let files = filter(files, "v:val !~ '/.$'")

  let files = map(
        \ files, "{
        \    'word' : v:val,
        \    'orig' : v:val,
        \    'action__is_directory' : isdirectory(v:val),
        \ }")

  if a:complete_str =~ '^\$\h\w*'
    let env = matchstr(a:complete_str, '^\$\h\w*')
    let env_ev = eval(env)
    if env_ev == ''
      return []
    endif
    if vimshell#util#is_windows()
      let env_ev = substitute(env_ev, '\\', '/', 'g')
    endif
    let len_env = len(env_ev)
  else
    let env = ''
    let env_ev = ''
    let len_env = 0
  endif

  let home_pattern = '^'.
        \ vimshell#util#substitute_path_separator(
        \ expand('~')).'/'
  let exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')

  let candidates = []
  for dict in files
    let dict.orig = dict.word

    if len_env != 0 && dict.word[: len_env-1] == env_ev
      let dict.word = env . dict.word[len_env :]
    endif

    let abbr = dict.word
    if dict.action__is_directory && dict.word !~ '/$'
      let abbr .= '/'
      if vimshell#util#is_auto_delimiter()
        let dict.word .= '/'
      endif
    elseif vimshell#util#is_windows()
      if '.'.fnamemodify(dict.word, ':e') =~ exts
        let abbr .= '*'
      endif
    elseif executable(dict.word)
      let abbr .= '*'
    endif
    let dict.abbr = abbr

    if a:complete_str =~ '^\~/'
      let dict.word = substitute(dict.word, home_pattern, '\~/', '')
      let dict.abbr = substitute(dict.abbr, home_pattern, '\~/', '')
    endif

    " Escape word.
    let dict.word = escape(dict.word, ' ;*?[]"={}''')

    call add(candidates, dict)
  endfor

  return candidates
endfunction"}}}

" vim: foldmethod=marker
