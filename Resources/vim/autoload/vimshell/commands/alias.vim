"=============================================================================
" FILE: alias.vim
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
      \ 'name' : 'alias',
      \ 'kind' : 'special',
      \ 'description' : 'alias {alias-name} = {command}',
      \}
function! s:command.execute(args, context) abort "{{{
  let args = join(a:args)

  if empty(a:args)
    " View all aliases.
    for alias in keys(b:vimshell.alias_table)
      call vimshell#print_line(a:context.fd,
            \ printf('%s=%s', alias, vimshell#helpers#get_alias(alias)))
    endfor
  elseif args =~ vimshell#helpers#get_alias_pattern().'$'
    " View alias.
    call vimshell#print_line(a:context.fd,
          \ printf('%s=%s', a:args[0], vimshell#helpers#get_alias(a:args[0])))
  else
    " Define alias.

    " Parse command line.
    let alias_name = matchstr(args,
          \ vimshell#helpers#get_alias_pattern().'\ze\s*=\s*')

    " Next.
    if alias_name == ''
      throw 'Wrong syntax: ' . args
    endif

    " Skip =.
    let expression = substitute(args[matchend(args, '\s*=\s*') :],
          \ '^[''"]\|[''"]$', '', 'g')

    call vimshell#helpers#set_alias(alias_name, expression)
  endif
endfunction"}}}

function! vimshell#commands#alias#define() abort
  return s:command
endfunction
