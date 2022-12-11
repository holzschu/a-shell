"=============================================================================
" FILE: vexe.vim
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
      \ 'name' : 'vexe',
      \ 'kind' : 'special',
      \ 'description' : 'vexe {expression}',
      \}
function! s:command.execute(args, context) abort "{{{
  " Execute vim command.
  let [args, options] = vimshell#parser#getopt(a:args, {
        \ 'noarg' : ['--insert'],
        \ }, {
        \ '--insert' : 0,
        \ })

  let context = a:context
  let context.fd = a:context.fd
  call vimshell#set_context(context)

  let old_pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.') ]

  let verbose = tempname()
  let [verbosefile_save, verbose_save] = [&verbosefile, &verbose]
  try
    let &verbosefile = verbose
    let &verbose = 0

    for command in split(join(args), '\n')
      silent! execute command
    endfor
  finally
    let [&verbosefile, &verbose] = [verbosefile_save, verbose_save]
  endtry

  let _ = join(readfile(verbose), "\n")[1:]
  call delete(verbose)

  let pos = [ tabpagenr(), winnr(), bufnr('%'), getpos('.') ]
  let bufnr = bufnr('%')

  noautocmd call vimshell#helpers#restore_pos(old_pos)

  if bufnr('%') != bufnr
    call vimshell#next_prompt(a:context)
    noautocmd call vimshell#helpers#restore_pos(pos)
    doautocmd BufRead
    if options['--insert']
      startinsert
    else
      stopinsert
    endif
    return 1
  elseif _ != ''
    call vimshell#print_line(a:context.fd, _)
  endif
endfunction"}}}

function! vimshell#commands#vexe#define() abort
  return s:command
endfunction
