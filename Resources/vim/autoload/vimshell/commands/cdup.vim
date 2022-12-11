"=============================================================================
" FILE: cdup.vim
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
      \ 'name' : 'cdup',
      \ 'kind' : 'internal',
      \ 'description' : 'cdup {ancestor-directory-name}',
      \}
function! s:command.execute(args, context) abort "{{{
  " Move to parent directory.

  if empty(a:args)
    let directory = '..'
  else
    let current_dir = b:vimshell.current_dir
    let target = get(a:args, 0)

    let directory = matchstr(current_dir,
          \ '.*/\V' . escape(target, '\') . '/')

    if directory == ''
      " Try partial match.
      let directory = matchstr(current_dir,
            \ '.*/.*\V' . escape(target, '\') . '\m.*/')
    endif

    if directory == ''
      call vimshell#error_line(a:context.fd,
            \ printf('%s : Can''t find "%s" directory in "%s"',
            \ self.name, target, b:vimshell.current_dir))
      return 0
    endif
  endif

  return vimshell#helpers#execute_internal_command('cd',
        \ [directory], a:context)
endfunction"}}}

function! s:command.complete(args) abort "{{{
  return split(b:vimshell.current_dir, '/')
endfunction"}}}

function! vimshell#commands#cdup#define() abort
  return s:command
endfunction
