"=============================================================================
" FILE: vimsh.vim
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
      \ 'name' : 'vimsh',
      \ 'kind' : 'internal',
      \ 'description' : 'vimsh [{filename}]',
      \}
function! s:command.execute(args, context) abort "{{{
  " Create new vimshell or execute script.
  if empty(a:args)
    let bufnr = bufnr('%')
    call vimshell#init#_start(getcwd(), {'create' : 1})
    execute 'buffer' bufnr

    return
  endif

  " Filename escape.
  let filename = join(a:args, ' ')

  if !filereadable(filename)
    " Error.
    call vimshell#error_line(a:context.fd,
          \ printf('vimsh: Not found the script "%s".', filename))
    return
  endif

  let context = vimshell#init#_context({
        \  'has_head_spaces' : 0, 'is_interactive' : 0,
        \ })
  let i = 0
  let lines = readfile(filename)
  let max = len(lines)

  while i < max
    let script = lines[i]

    " Parse check.
    while i+1 < max
      try
        call vimshell#parser#check_script(script)
        break
      catch /^Exception: Quote/
        " Join to next line.
        let script .= "\<NL>" . lines[i+1]
        let i += 1
      endtry
    endwhile

    try
      call vimshell#parser#eval_script(script, context)
    catch
      let message = (v:exception !~# '^Vim:')?
            \ v:exception : v:exception . ' ' . v:throwpoint
      call vimshell#error_line(context.fd,
            \ printf('%s(%d): %s', join(a:args), i, message))
      return
    endtry

    let i += 1
  endwhile
endfunction"}}}

function! vimshell#commands#vimsh#define() abort
  return s:command
endfunction
