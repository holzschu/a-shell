"=============================================================================
" FILE: sexe.vim
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

let s:command = {
      \ 'name' : 'sexe',
      \ 'kind' : 'special',
      \ 'description' : 'sexe {command}',
      \}
function! s:command.execute(args, context) abort "{{{
  let [args, options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding']
        \})
  if !has_key(options, '--encoding')
    let options['--encoding'] = 'char'
  endif

  " Execute shell command.
  let cmdline = ''
  for arg in args
    if vimshell#util#is_windows()
      let arg = substitute(arg, '"', '\\"', 'g')
      let arg = substitute(arg, '[<>|^]', '^\0', 'g')
      let cmdline .= '"' . arg . '" '
    else
      let cmdline .= shellescape(arg) . ' '
    endif
  endfor

  if vimshell#util#is_windows()
    let cmdline = '"' . cmdline . '"'
  endif

  " Set redirection.
  let null = ''
  if a:context.fd.stdin == ''
    let stdin = ''
  elseif a:context.fd.stdin == '/dev/null'
    let null = tempname()
    call writefile([], null)

    let stdin = '<' . null
  else
    let stdin = '<' . a:context.fd.stdin
  endif

  echo 'Running command.'

    " Convert encoding.
  let cmdline = vimproc#util#iconv(cmdline, &encoding, options['--encoding'])
  let stdin = vimproc#util#iconv(stdin, &encoding, options['--encoding'])

  " Set environment variables.
  let environments_save = vimshell#util#set_variables({
        \ '$TERMCAP' : 'COLUMNS=' . vimshell#helpers#get_winwidth(),
        \ '$COLUMNS' : vimshell#helpers#get_winwidth(),
        \ '$LINES' : g:vimshell_scrollback_limit,
        \ '$EDITOR' : vimshell#helpers#get_editor_name(),
        \ '$GIT_EDITOR' : vimshell#helpers#get_editor_name(),
        \ '$PAGER' : g:vimshell_cat_command,
        \ '$GIT_PAGER' : g:vimshell_cat_command,
        \})

  let result = system(printf('%s %s', cmdline, stdin))

  " Restore environment variables.
  call vimshell#util#restore_variables(environments_save)

  " Convert encoding.
  let result = vimproc#util#iconv(result, options['--encoding'], &encoding)

  call vimshell#print(a:context.fd, result)
  redraw
  echo ''

  if null != ''
    call delete(null)
  endif

  let b:vimshell.system_variables['status'] = v:shell_error

  return
endfunction"}}}

function! vimshell#commands#sexe#define() abort
  return s:command
endfunction
