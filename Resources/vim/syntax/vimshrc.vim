"=============================================================================
" FILE: syntax/vimshrc.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Usage: Just source this file.
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

if version < 700
  syntax clear
elseif exists('b:current_syntax')
  finish
endif

syntax match   vimshrcCommand
      \ '\%(^\|[;|]\)\s*\zs[[:alnum:]_.][[:alnum:]_.-]\+' contained
syntax match   vimshrcVariable
      \ '$\h\w*' contained
syntax match   vimshrcVariable
      \ '$$\h\w*' contained
syntax region   vimshrcVariable
      \ start=+${+ end=+}+ contained
syntax region   vimshrcString
      \ start=+'+ end=+'+ oneline contained
syntax region   vimshrcString
      \ start=+"+ end=+"+ contains=VimShellQuoted oneline contained
syntax region   vimshrcString
      \ start=+`+ end=+`+ oneline contained
syntax match   vimshrcString
      \ '[''"`]$' contained
syntax match   vimshrcComment
      \ '#.*$' contained
syntax match   vimshrcConstants
      \ '[+-]\=\<\d\+\>' contained
syntax match   vimshrcConstants
      \ '[+-]\=\<0x\x\+\>' contained
syntax match   vimshrcConstants
      \ '[+-]\=\<0\o\+\>' contained
syntax match   vimshrcConstants
      \ '[+-]\=\d\+#[-+]\=\w\+\>' contained
syntax match   vimshrcConstants
      \ '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>' contained
syntax match   vimshrcArguments
      \ '\s-\=-[[:alnum:]-]\+=\=' contained
syntax match   vimshrcQuoted
      \ '\\.' contained
syntax match   vimshrcSpecial
      \ '[|<>;&;]' contained
if vimshell#util#is_windows()
  syntax match   vimshrcArguments
        \ '\s/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
  syntax match   vimshrcDirectory
        \ '\%(\f\s\?\)\+[/\\]\ze\%(\s\|$\)'
else
  syntax match   vimshrcDirectory
        \ '\%(\f\s\?\)\+/\ze\%(\s\|$\)'
endif

syntax region   vimshrcVimShellScriptRegion
      \ start='\zs\<\f\+' end='\zs$'
      \ contains=vimshrcCommand,vimshrcVariable,vimshrcString,
      \vimshrcComment,vimshrcConstants,vimshrcArguments,
      \vimshrcQuoted,vimshrcSpecial,vimshrcDirectory
syntax region   vimshrcCommentRegion  start='#' end='\zs$'
syntax cluster  vimshrcBodyList
      \ contains=vimshrcVimShellScriptRegion,vimshrcComment

unlet! b:current_syntax
syntax include @vimshrcVimScript syntax/vim.vim
syntax region vimshrcVimScriptRegion
      \ start=-\<vexe\s\+\z(["']\)\zs$- end=+\z1\zs$+ contains=@vimshrcVimScript
syntax cluster vimshrcBodyList add=vimshrcVimScriptRegion

highlight default link vimshrcQuoted Special
highlight default link vimshrcString String
highlight default link vimshrcArguments Type
highlight default link vimshrcConstants Constant
highlight default link vimshrcSpecial PreProc
highlight default link vimshrcVariable Identifier
highlight default link vimshrcComment Comment
highlight default link vimshrcCommentRegion Comment
highlight default link vimshrcNormal Normal

highlight default link vimshrcCommand Statement
highlight default link vimshrcDirectory Preproc

let b:current_syntax = 'vimshrc'
