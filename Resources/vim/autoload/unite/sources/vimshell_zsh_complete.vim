"=============================================================================
" FILE: vimshell_zsh_complete.vim
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

let s:script_path = expand('<sfile>:p:h')
      \ .'/vimshell_zsh_complete/complete.zsh'

function! unite#sources#vimshell_zsh_complete#define() abort "{{{
  return (executable('zsh') && !vimshell#util#is_windows()) ?
        \ s:source : {}
endfunction "}}}

let s:source = {
      \ 'name': 'vimshell/zsh_complete',
      \ 'hooks' : {},
      \ 'max_candidates' : 100,
      \ 'syntax' : 'uniteSource__VimshellZshComplete',
      \ 'is_listed' : 0,
      \ }

function! s:source.hooks.on_init(args, context) abort "{{{
  let a:context.source__input = vimshell#get_cur_text()

  try
    let args = vimshell#helpers#get_current_args(a:context.source__input)

    if len(args) <= 1
      let pos = vimshell#get_prompt_length()
    else
      if a:context.source__input =~ '\s\+$'
        " Add blank argument.
        call add(args, '')
      endif

      let pos = col('.')-len(args[-1])
    endif
  catch /^Exception:/
    let pos = -1
  endtry

  let a:context.source__cur_keyword_pos = pos
endfunction"}}}
function! s:source.hooks.on_syntax(args, context) abort "{{{
  syntax match uniteSource__VimshellZshCompleteDescriptionLine / -- .*$/
        \ contained containedin=uniteSource__VimshellZshComplete
  syntax match uniteSource__VimshellZshCompleteDescription /.*$/
        \ contained containedin=uniteSource__VimshellZshCompleteDescriptionLine
  syntax match uniteSource__VimshellZshCompleteMarker / -- /
        \ contained containedin=uniteSource__VimshellZshCompleteDescriptionLine
  highlight default link uniteSource__VimshellZshCompleteMarker Special
  highlight default link uniteSource__VimshellZshCompleteDescription Comment
endfunction"}}}
function! s:source.hooks.on_close(args, context) abort "{{{
  if has_key(a:context, 'source__proc')
    call a:context.source__proc.waitpid()
  endif
endfunction"}}}
function! s:source.hooks.on_post_filter(args, context) abort "{{{
  for candidate in a:context.candidates
    let candidate.kind = 'completion'
    let candidate.action__complete_word = candidate.word
    let candidate.action__complete_pos =
          \ a:context.source__cur_keyword_pos
  endfor
endfunction"}}}
function! s:source.gather_candidates(args, context) abort "{{{
  let a:context.source__proc = vimproc#plineopen3('zsh -i -f', 1)

  call a:context.source__proc.stdin.write(
        \ 'source ' . string(s:script_path) . "\<LF>")

  call a:context.source__proc.stdin.write(
        \ a:context.source__input . "\<Tab>\<C-u>exit\<LF>")

  return []
endfunction "}}}

function! s:source.async_gather_candidates(args, context) abort "{{{
  if !has_key(a:context, 'source__proc')
    return []
  endif

  let stderr = a:context.source__proc.stderr
  if !stderr.eof
    " Print error.
    let errors = filter(stderr.read_lines(-1, 100),
          \ "v:val !~ '^\\s*$'")
    if !empty(errors)
      call unite#print_source_error(errors, s:source.name)
    endif
  endif

  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    call unite#print_source_message('Completed.', s:source.name)
    let a:context.is_async = 0
  endif

  let lines = stdout.read_lines(-1, 100)

  if g:vimshell_enable_debug
    echomsg string(lines)
  endif

  return s:convert_lines(lines)
endfunction "}}}

function! unite#sources#vimshell_zsh_complete#start_complete(is_insert) abort "{{{
  if !exists(':Unite')
    call vimshell#echo_error('unite.vim is not installed.')
    call vimshell#echo_error(
          \ 'Please install unite.vim Ver.1.5 or above.')
    return ''
  elseif unite#version() < 300
    call vimshell#echo_error('Your unite.vim is too old.')
    call vimshell#echo_error(
          \ 'Please install unite.vim Ver.3.0 or above.')
    return ''
  endif

  let cmdline = vimshell#get_cur_text()
  try
    let args = vimshell#helpers#get_current_args(cmdline)
  catch /^Exception:/
    return ''
  endtry

  if empty(args) || cmdline =~ '\\\@!\s\+$'
    " Add blank argument.
    call add(args, '')
  endif

  return unite#start_complete(['vimshell/zsh_complete'], {
        \ 'start_insert' : a:is_insert,
        \ 'input' : args[-1],
        \ })
endfunction "}}}

function! s:convert_lines(lines) abort
  let _ = []
  for line in filter(copy(a:lines),
        \ "v:val !~ '\\r' && v:val !~ '^% '")
    if line ==# 'files'
      " Dummy candidate.
    elseif stridx(line, ' -- ') > 0
      call add(_, { 'word' :
            \ split(line, '\\\@<!\s\+')[0], 'abbr' : line })
    else
      call extend(_, map(split(line, '\\\@<!\s\+'),
            \ "{'word' : v:val}"))
    endif
  endfor

  return _
endfunction

" vim: foldmethod=marker
