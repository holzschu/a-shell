"=============================================================================
" FILE: hook.vim
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

function! vimshell#hook#call(hook_point, context, args) abort "{{{
  " There are cases when this variable doesn't
  " exist
  " USE: 'b:interactive.is_close_immediately = 1' to replicate
  if !exists('b:interactive')
    return
  end

  if !a:context.is_interactive
        \ || !has_key(b:interactive, 'hook_functions_table')
        \ || !has_key(b:interactive.hook_functions_table, a:hook_point)
    return
  endif

  let context = copy(a:context)
  let context.is_interactive = 0
  call vimshell#set_context(context)

  " Call hook function.
  let table = b:interactive.hook_functions_table[a:hook_point]
  for key in sort(keys(table))
    call call(table[key], [a:args, context], {})
  endfor
endfunction"}}}
function! vimshell#hook#call_filter(hook_point, context, cmdline) abort "{{{
  if !exists('b:interactive') || !a:context.is_interactive
        \ || !has_key(b:interactive.hook_functions_table, a:hook_point)
    return a:cmdline
  endif

  let context = copy(a:context)
  let context.is_interactive = 0
  call vimshell#set_context(context)

  " Call hook function.
  let cmdline = a:cmdline
  let table = b:interactive.hook_functions_table[a:hook_point]
  for key in sort(keys(table))
    let ret = call(table[key], [cmdline, context], {})

    if type(ret) != type(0)
      " Use new value.
      let cmdline = ret
    endif
  endfor

  return cmdline
endfunction"}}}
function! vimshell#hook#set(hook_point, func_list) abort "{{{
  if !exists('b:interactive')
    return
  endif

  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    let b:interactive.hook_functions_table[a:hook_point] = {}
  endif

  let cnt = 1
  let b:interactive.hook_functions_table[a:hook_point] = {}
  for Func in a:func_list
    let b:interactive.hook_functions_table[a:hook_point][cnt] = Func

    let cnt += 1
  endfor
endfunction"}}}
function! vimshell#hook#get(hook_point) abort "{{{
  if !exists('b:interactive')
    return
  endif

  return get(b:interactive.hook_functions_table, a:hook_point, {})
endfunction"}}}
function! vimshell#hook#add(hook_point, hook_name, func) abort "{{{
  if !exists('b:interactive')
    return
  endif

  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    let b:interactive.hook_functions_table[a:hook_point] = {}
  endif

  let b:interactive.hook_functions_table[a:hook_point][a:hook_name] = a:func
endfunction"}}}
function! vimshell#hook#remove(hook_point, hook_name) abort "{{{
  if !exists('b:interactive')
    return
  endif

  if !has_key(b:interactive.hook_functions_table, a:hook_point)
    let b:interactive.hook_functions_table[a:hook_point] = {}
  endif

  if has_key(b:interactive.hook_functions_table[a:hook_point], a:hook_name)
    call remove(b:interactive.hook_functions_table[a:hook_point], a:hook_name)
  endif
endfunction"}}}

" vim: foldmethod=marker
