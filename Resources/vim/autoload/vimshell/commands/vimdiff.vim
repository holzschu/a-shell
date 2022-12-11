"=============================================================================
" FILE: vimdiff.vim
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
      \ 'name' : 'vimdiff',
      \ 'kind' : 'internal',
      \ 'description' : 'vimdiff {filename1} {filename2}',
      \}
function! s:command.execute(args, context) abort "{{{
  let [args, options] = vimshell#parser#getopt(a:args, {
        \ 'arg=' : ['--split'],
        \ }, {
        \ '--split' : g:vimshell_split_command,
        \ })

  if len(args) != 2
    " Error.
    call vimshell#error_line(a:context.fd, 'Usage: vimdiff file1 file2')
    return
  endif

  " Save current directiory.
  let cwd = getcwd()

  let [new_pos, old_pos] = vimshell#helpers#split(options['--split'])

  try
    silent execute 'edit' fnameescape(args[0])
  catch
    echohl Error | echomsg v:errmsg | echohl None
  endtry

  let [new_pos[2], new_pos[3]] = [bufnr('%'), getpos('.')]

  call vimshell#cd(cwd)

  execute 'vertical diffsplit' fnameescape(a:args[1])

  noautocmd call vimshell#helpers#restore_pos(old_pos)

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#next_prompt(a:context, 0)
    noautocmd call vimshell#helpers#restore_pos(new_pos)
    stopinsert
  endif
endfunction"}}}

function! vimshell#commands#vimdiff#define() abort
  return s:command
endfunction
