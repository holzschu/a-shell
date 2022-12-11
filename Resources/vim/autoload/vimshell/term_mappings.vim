"=============================================================================
" FILE: term_mappings.vim
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

function! vimshell#term_mappings#define_default_mappings() abort "{{{
  " Plugin key-mappings. "{{{
  nnoremap <buffer><silent> <Plug>(vimshell_term_interrupt)
        \ :<C-u>call vimshell#interactive#hang_up(bufname('%'))<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_term_exit)
        \ :<C-u>call vimshell#interactive#quit_buffer()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_term_start_insert)
        \ :<C-u>call <SID>start_insert()<CR>
  nnoremap <buffer><silent> <Plug>(vimshell_term_execute_line)
        \ :<C-u>call <SID>execute_line()<CR>
  inoremap <buffer><silent><expr> <Plug>(vimshell_term_send_escape)
        \ vimshell#term_mappings#send_key("\<ESC>")
  inoremap <buffer><silent> <Plug>(vimshell_term_send_input)
        \ <C-o>:call vimshell#interactive#send_input()<CR>
  "}}}

  for lhs in [
        \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
        \ 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
        \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
        \ 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        \ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
        \ '!', '@', '#', '$', '^', '&', '*', '(', ')',
        \ '-', '_', '=', '+', '\', '`', '~',
        \ '[', ']', '{', '}', ':', ';', '''', '"', ',', '<', '.', '>', '/', '?',
        \ ]

    execute 'inoremap <buffer><silent><expr>' lhs
          \ 'vimshell#term_mappings#send_key('. string(lhs) .')'
    "execute 'inoremap <buffer><silent>' lhs printf('<C-o>:call vimshell#interactive#send_char(%s)<CR>', char2nr(lhs))
  endfor

  for [key, value] in items({
        \ '<C-a>' : "\<C-a>", '<C-b>' : "\<C-b>", '<C-c>' : "\<C-c>",
        \ '<C-d>' : "\<C-d>", '<C-e>' : "\<C-e>", '<C-f>' : "\<C-f>",
        \ '<C-g>' : "\<C-g>", '<C-h>' : "\<C-h>", '<C-i>' : "\<C-i>",
        \ '<C-j>' : "\<C-j>", '<C-k>' : "\<C-k>", '<C-l>' : "\<C-l>",
        \ '<C-m>' : "\<LF>",  '<C-n>' : "\<C-n>", '<C-o>' : "\<C-o>",
        \ '<C-p>' : "\<C-p>", '<C-q>' : "\<C-q>", '<C-r>' : "\<C-r>",
        \ '<C-s>' : "\<C-s>", '<C-t>' : "\<C-t>", '<C-u>' : "\<C-u>",
        \ '<C-v>' : "\<C-v>", '<C-w>' : "\<C-w>", '<C-x>' : "\<C-x>",
        \ '<C-y>' : "\<C-y>", '<C-z>' : "\<C-z>",
        \ '<C-^>' : "\<C-^>", '<C-_>' : "\<C-_>", '<C-\>' : "\<C-\>",
        \ '<Bar>' : '|',      '<Space>' : ' ',
        \ })

    execute 'inoremap <buffer><silent>' key
          \ printf('<C-o>:call vimshell#interactive#send_char(%s)<CR>', char2nr(value))
  endfor

  for [key, value] in items({
        \ '<Home>'   : "\<ESC>OH",   '<End>'      : "\<ESC>OF",
        \ '<Del>'    : "\<ESC>[3~",  '<BS>'       : "\<C-h>",
        \ '<Up>'     : "\<ESC>[A",   '<Down>'     : "\<ESC>[B",
        \ '<Left>'   : "\<ESC>[D",   '<Right>'    : "\<ESC>[C",
        \ '<PageUp>' : "\<ESC>[5~",  '<PageDown>' : "\<ESC>[6~",
        \ '<F1>'     : "\<ESC>[11~", '<F2>'       : "\<ESC>[12~",
        \ '<F3>'     : "\<ESC>[13~", '<F4>'       : "\<ESC>[14~",
        \ '<F5>'     : "\<ESC>[15~", '<F6>'       : "\<ESC>[17~",
        \ '<F7>'     : "\<ESC>[18~", '<F8>'       : "\<ESC>[19~",
        \ '<F9>'     : "\<ESC>[20~", '<F10>'      : "\<ESC>[21~",
        \ '<F11>'    : "\<ESC>[23~", '<F12>'      : "\<ESC>[24~",
        \ '<Insert>' : "\<ESC>[2~",
        \ })

    execute 'inoremap <buffer><silent>' key
          \ printf('<C-o>:call vimshell#interactive#send_char(%s)<CR>',
          \     string(map(split(value, '\zs'), 'char2nr(v:val)')))
  endfor

  if exists('g:vimshell_no_default_keymappings')
        \ && g:vimshell_no_default_keymappings
    return
  endif

  " Normal mode key-mappings.
  nmap <buffer> <C-c>     <Plug>(vimshell_term_interrupt)
  nmap <buffer> q         <Plug>(vimshell_term_exit)
  nmap <buffer> i         <Plug>(vimshell_term_start_insert)
  nmap <buffer> I         <Plug>(vimshell_term_start_insert)
  nmap <buffer> a         <Plug>(vimshell_term_start_insert)
  nmap <buffer> A         <Plug>(vimshell_term_start_insert)
  nmap <buffer> <CR>      <Plug>(vimshell_term_execute_line)

  " Insert mode key-mappings.
  imap <buffer> <ESC><ESC>         <Plug>(vimshell_term_send_escape)
  imap <buffer> <C-Space>  <C-@>
  imap <buffer> <C-@>              <Plug>(vimshell_term_send_input)
endfunction"}}}
function! vimshell#term_mappings#send_key(key) abort "{{{
  return printf("\<C-o>:call vimshell#interactive#send_char(%s)\<CR>", char2nr(a:key))
endfunction"}}}
function! vimshell#term_mappings#send_keys(keys) abort "{{{
  return printf("\<C-o>:call vimshell#interactive#send_char(%s)\<CR>", string(map(split(a:keys, '\zs'), 'char2nr(v:val)')))
endfunction"}}}

" vimshell interactive key-mappings functions.
function! s:start_insert() abort "{{{
  setlocal modifiable
  startinsert
endfunction "}}}
function! s:execute_line() abort "{{{
  " Search cursor file.
  let filename = unite#util#substitute_path_separator(substitute(
        \ expand('<cfile>'), ' ', '\\ ', 'g'))

  " Convert encoding.
  let filename = vimproc#util#iconv(filename, &encoding, 'char')

  " Execute cursor file.
  if filename =~ '^\%(https\?\|ftp\)://'
    " Open uri.
    call vimshell#open(filename)
    return
  endif
endfunction"}}}

" vim: foldmethod=marker
