"=============================================================================
" FILE: handlers.vim
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

let s:save_cpo = &cpo
set cpo&vim

function! vimshell#handlers#_on_bufwin_enter(bufnr) abort "{{{
  if a:bufnr != bufnr('%') && bufwinnr(a:bufnr) > 0
    let winnr = winnr()
    execute bufwinnr(a:bufnr) 'wincmd w'
  endif

  if !exists('t:vimshell')
    call vimshell#init#tab_variable()
  endif
  let t:vimshell.last_vimshell_bufnr = bufnr('%')

  try
    if !exists('b:vimshell')
      return
    endif

    if has('conceal')
      setlocal conceallevel=3
      setlocal concealcursor=nvi
    endif

    setlocal nolist

    if !exists('b:vimshell') ||
          \ !isdirectory(b:vimshell.current_dir)
      return
    endif

    call vimshell#cd(fnamemodify(b:vimshell.current_dir, ':p'))

    " Redraw right prompt.
    let winwidth = (vimshell#helpers#get_winwidth()+1)/2*2
    for [line, prompts] in items(b:vimshell.prompts_save)
      if getline(line) =~ '^\[%] .*\S$'
            \ && prompts.winwidth != winwidth
        let right_prompt = prompts.right_prompt
        let user_prompt_last = prompts.user_prompt_last

        let padding_len =
              \ (len(user_prompt_last)+
              \  len(right_prompt)+1
              \          > winwidth) ?
              \ 1 : winwidth - (len(user_prompt_last)+len(right_prompt))
        let secondary = printf('%s%s%s', user_prompt_last,
              \ repeat(' ', padding_len), right_prompt)
        call setline(line, secondary)
      endif
    endfor

    call vimshell#handlers#_restore_statusline()
  finally
    if exists('winnr')
      execute winnr.'wincmd w'
    endif
  endtry
endfunction"}}}

function! vimshell#handlers#_restore_statusline() abort  "{{{
  if &filetype !=# 'vimshell' || !g:vimshell_force_overwrite_statusline
    return
  endif

  if &l:statusline != b:vimshell.statusline
    " Restore statusline.
    let &l:statusline = b:vimshell.statusline
  endif
endfunction"}}}


let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
