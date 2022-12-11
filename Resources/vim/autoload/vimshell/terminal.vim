"=============================================================================
" FILE: terminal.vim
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

function! vimshell#terminal#init() abort "{{{
  let b:interactive.terminal = {
        \ 'syntax_names' : {},
        \ 'syntax_commands' : {},
        \ 'syntax_highlights' : {},
        \ 'titlestring' : &titlestring,
        \ 'titlestring_save' : &titlestring,
        \ 'save_pos' : getpos('.')[1 : 2],
        \ 'region_top' : 0,
        \ 'region_bottom' : 0,
        \ 'standard_character_set' : 'United States',
        \ 'alternate_character_set' : 'United States',
        \ 'current_character_set' : 'United States',
        \ 'is_error' : 0,
        \ 'wrap' : &l:wrap,
        \ 'buffer' : '',
        \}

  call vimshell#terminal#init_highlight()
endfunction"}}}
function! vimshell#terminal#init_highlight() abort "{{{
  if s:use_conceal()
    syntax match vimshellEscapeSequenceConceal
          \ contained conceal    '\e\[[0-9;]*m'
    syntax match vimshellEscapeSequenceMarker
          \ conceal               '\e\[0*m\|\e0m\[\|\e]0;'
  endif

  if !exists('b:interactive.terminal')
    return
  endif

  let terminal = b:interactive.terminal
  for syntax_name in values(terminal.syntax_names)
    execute 'syntax region' syntax_name
          \ terminal.syntax_commands[syntax_name]
    execute 'highlight' syntax_name
          \ terminal.syntax_highlights[syntax_name]
  endfor
endfunction"}}}
function! vimshell#terminal#print(string, is_error) abort "{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  setlocal modifiable
  if g:vimshell_enable_debug
    echomsg 'print string = ' . string(a:string)
  endif

  call vimshell#util#disable_auto_complete()

  if &filetype ==# 'vimshell' &&
        \ empty(b:vimshell.continuation) && (vimshell#check_prompt()
        \ || vimshell#util#head_match(getline('.'),
        \     vimshell#get_secondary_prompt()))
    " Move line.
    call append(line('.'), '')
    call cursor(line('.')+1, 0)
  endif

  let current_line = getline('.')

  let s:virtual = {
        \ 'lines' : {},
        \ 'col' : 0,
        \ 'line' : 0,
        \ }
  let s:virtual.lines = {}
  let [s:virtual.line, s:virtual.col] =
        \ s:get_virtual_col(line('.'), col('.'))
  if g:vimshell_enable_debug
    echomsg '[s:virtual.line, s:virtual.col] = ' .
          \ string([s:virtual.line, s:virtual.col])
  endif
  let s:virtual.lines[s:virtual.line] = current_line

  if b:interactive.type !=# 'terminal' && a:string !~ '[\e\b]'
    call s:optimized_print(a:string, a:is_error)
    return
  endif

  let b:interactive.terminal.is_error = a:is_error

  let newstr = s:check_str(a:string)

  " Print rest string.
  call s:output_string(newstr)

  " Set lines.
  for linenr in sort(map(keys(s:virtual.lines),
        \ 'str2nr(v:val)'), 's:sortfunc')
    call setline(linenr, substitute(
          \ s:virtual.lines[linenr], '[^!]\zs!\{6}\ze[^!]', '', 'g'))
  endfor

  call s:set_cursor()
endfunction"}}}
function! vimshell#terminal#set_title() abort "{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  let &titlestring = b:interactive.terminal.titlestring
endfunction"}}}
function! vimshell#terminal#restore_title() abort "{{{
  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  let &titlestring = b:interactive.terminal.titlestring_save
endfunction"}}}
function! vimshell#terminal#clear_highlight() abort "{{{
  if !s:use_conceal()
    return
  endif

  if !has_key(b:interactive, 'terminal')
    call vimshell#terminal#init()
  endif

  for syntax_names in values(b:interactive.terminal.syntax_names)
    execute 'highlight clear' syntax_names
    execute 'syntax clear' syntax_names
  endfor

  let b:interactive.terminal.syntax_names = {}
  let b:interactive.terminal.syntax_commands = {}
  let b:interactive.terminal.syntax_highlights = {}

  " Restore wrap.
  let &l:wrap = b:interactive.terminal.wrap
endfunction"}}}

function! s:check_str(string) abort "{{{
  " Optimize checkstr.
  let string = b:interactive.terminal.buffer . a:string
  let b:interactive.terminal.buffer = ''
  while string =~ '\%(\e\[[0-9;]*m\)\{2,}'
    let string = substitute(string,
          \ '\e\[[0-9;]*\zsm\e\[\ze[0-9;]*m', ';', 'g')
  endwhile

  let max = len(string)
  let newstr = ''
  let pos = 0

  while pos < max
    let char = string[pos]

    if char !~ '[[:cntrl:]]' "{{{
      let newstr .= char
      let pos += 1
      continue
      "}}}
    elseif char == "\<C-h>" "{{{
      " Print rest string.
      call s:output_string(newstr)
      let newstr = ''

      if pos + 1 < max && string[pos+1] == "\<C-h>"
        " <C-h><C-h>
        call s:control.delete_multi_backword_char()
        let pos += 2
      else
        " <C-h>
        call s:control.delete_backword_char()
        let pos += 1
      endif

      continue
      "}}}
    elseif char == "\<ESC>" "{{{
      " Check escape sequence.
      let checkstr = string[pos+1 :]
      if checkstr == ''
        " Incomplete sequence.
        let b:interactive.terminal.buffer = string[pos :]
        break
      endif

      " Check CSI pattern.
      if checkstr =~ '^\[[0-9;]*.'
        let matchstr = matchstr(checkstr, '^\[[0-9;]*.')

        if has_key(s:escape_sequence_csi, matchstr[-1:])
          call s:output_string(newstr)
          let newstr = ''

          call call(s:escape_sequence_csi[matchstr[-1:]],
                \ [matchstr], s:escape)

          let pos += len(matchstr) + 1
          continue
        endif
      endif

      " Check simple pattern.
      let checkchar1 = checkstr[0]
      if has_key(s:escape_sequence_simple_char1, checkchar1) "{{{
        call s:output_string(newstr)
        let newstr = ''

        call call(s:escape_sequence_simple_char1[checkchar1], [''], s:escape)

        let pos += 2
        continue
      endif"}}}
      let checkchar2 = checkstr[: 1]
      if checkchar2 != '' &&
            \ has_key(s:escape_sequence_simple_char2, checkchar2) "{{{
        call s:output_string(newstr)
        let newstr = ''

        call call(s:escape_sequence_simple_char2[checkchar2], [''], s:escape)

        let pos += 3
        continue
      endif"}}}

      let matched = 0
      " Check match pattern.
      for pattern in keys(s:escape_sequence_match) "{{{
        if checkstr =~ pattern
          let matched = 1

          " Print rest string.
          call s:output_string(newstr)
          let newstr = ''

          let matchstr = matchstr(checkstr, pattern)

          call call(s:escape_sequence_match[pattern], [matchstr], s:escape)

          let pos += len(matchstr) + 1
          break
        endif
      endfor"}}}

      if matched
        continue
      elseif checkstr !~ '\r\|\n'
        " Incomplete sequence.
        let b:interactive.terminal.buffer = string[pos :]
        break
      endif"}}}
    elseif has_key(s:control_sequence, char) "{{{
      " Check other pattern.
      " Print rest string.
      call s:output_string(newstr)
      let newstr = ''

      call call(s:control_sequence[char], [], s:control)

      let pos += 1
      continue
    endif"}}}

    let newstr .= char
    let pos += 1
  endwhile

  return newstr
endfunction "}}}
function! s:optimized_print(string, is_error) abort "{{{
  " Strip <CR>.
  let string = substitute(substitute(
        \ a:string, "\<C-g>", '', 'g'), '\r\+\n', '\n', 'g')

  if g:vimshell_enable_debug
    echomsg 'print optimized output string = ' . string(string)
  endif

  let lines = split(string, '\n', 1)

  if string =~ '\r'
    call s:print_with_redraw(a:is_error, lines)
  else
    call s:print_simple(a:is_error, lines)
  endif

  call cursor(0, col('$'))
  let [s:virtual.line, s:virtual.col] =
        \ s:get_virtual_col(line('.'), col('.'))
  call s:set_cursor()
endfunction"}}}
function! s:print_with_redraw(is_error, lines) abort "{{{
  let cnt = 1
  for line in a:lines
    if cnt != 1 ||
          \ (s:is_no_echoback() && getline('$') != '')
      call append('.', '')
      call cursor(line('.')+1, 0)
    endif

    let ls = map(split(line, '\r\ze.', 1), "substitute(v:val, '\\r', '', '')")

    if a:is_error
      call map(ls, "v:val != '' ? ('!!!'.v:val.'!!!') : v:val")
    endif

    for l in ls
      call setline('.', l)
      redraw
    endfor

    let cnt += 1
  endfor
endfunction"}}}
function! s:print_simple(is_error, lines) abort "{{{
  let lines = a:lines

  if a:is_error
    call map(lines, "v:val != '' ? ('!!!'.v:val.'!!!') : v:val")
  endif

  " Optimized print.
  if s:is_no_echoback()
    if line('$') == 1 && getline('$') == ''
      call setline('.', lines[0])
    else
      call append('.', lines[0])
    endif

    call cursor(line('.')+1, 0)
    call cursor(0, col('$'))
  elseif line('.') != b:interactive.echoback_linenr
    call setline('.', substitute(
          \ getline('.') . lines[0], '[^!]\zs!\{6}\ze[^!]', '', 'g'))
  endif

  let lines = lines[1:]

  call append('.', lines)
  call cursor(line('.') + len(lines), 0)
  call cursor(0, col('$'))
endfunction"}}}
function! s:set_cursor() abort "{{{
  " Get real pos(0 origin).
  let [line, col] = s:get_real_pos(
        \ s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)

  " Convert to 1 origin.
  let col += 1

  if g:vimshell_enable_debug
    echomsg 'set cursor = ' . string([line, col])
  endif

  " Move pos.
  call cursor(line, col)

  if b:interactive.type ==# 'terminal'
    let b:interactive.save_cursor = getpos('.')
  endif

  redraw
endfunction"}}}
function! s:is_no_echoback() abort "{{{
  return b:interactive.type ==# 'interactive'
          \ && vimshell#util#is_windows()
          \ && has_key(b:interactive, 'command')
          \ && !get(g:vimshell_interactive_echoback_commands,
          \        b:interactive.command, 0)
endfunction"}}}

function! s:init_terminal() abort "{{{
endfunction"}}}
function! s:output_string(string) abort "{{{
  if s:virtual.line == b:interactive.echoback_linenr
    if s:is_no_echoback()
      " no echoback command.
      let s:virtual.line += 1
      let s:virtual.lines[s:virtual.line] = a:string
      let s:virtual.col = len(a:string)
    endif

    return
  endif

  if g:vimshell_enable_debug
    echomsg 'print output string = ' . string(a:string)
  endif

  if a:string == ''
    return
  endif

  let string = a:string != '' && b:interactive.terminal.is_error ?
        \ '!!!' . a:string . '!!!' : a:string

  if b:interactive.terminal.current_character_set
        \ ==# 'Line Drawing'
    " Convert characters.
    let string = ''
    for c in split(a:string, '\zs')
      let string .= has_key(s:drawing_character_table, c)?
            \ s:drawing_character_table[c] : c
    endfor
  endif

  call s:set_screen_string(s:virtual.line, s:virtual.col, string)
endfunction"}}}
function! s:sortfunc(i1, i2) abort "{{{
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction"}}}
function! s:scroll_up(number) abort "{{{
  let line = b:interactive.terminal.region_bottom
  let end = b:interactive.terminal.region_top - a:number
  while line >= end
    let s:virtual.lines[line] = has_key(s:virtual.lines, line - a:number) ?
          \ s:virtual.lines[line - a:number] : getline(line - a:number)

    let line -= 1
  endwhile

  let i = 0
  while i < a:number
    let s:virtual.lines[b:interactive.terminal.region_top + i] = ''
    let i += 1
  endwhile
endfunction"}}}
function! s:scroll_down(number) abort "{{{
  let line = b:interactive.terminal.region_top
  let end = b:interactive.terminal.region_bottom - a:number
  while line <= end
    let s:virtual.lines[line] = has_key(s:virtual.lines, line + a:number) ?
          \ s:virtual.lines[line + a:number] : getline(line + a:number)

    let line += 1
  endwhile

  let i = 0
  while i < a:number
    let s:virtual.lines[b:interactive.terminal.region_bottom - i] = ''
    let i += 1
  endwhile
endfunction"}}}
function! s:use_conceal() abort "{{{
  return has('conceal')
endfunction"}}}

" Note: Real pos is 0 origin.
function! s:get_real_pos(line, col) abort "{{{
  let current_line = get(s:virtual.lines, a:line, getline(a:line))
  if a:col <= 1 && current_line !~ '\e\[[0-9;]*m'
    return [a:line, 0]
  endif

  return [a:line, vimshell#terminal#get_col(
        \ get(s:virtual.lines, a:line, getline(a:line)), -1, -1, a:col, 0)]
endfunction"}}}
function! s:get_virtual_col(line, col) abort "{{{
  let current_line = get(s:virtual.lines, a:line, getline(a:line))
  if a:col <= 0 && current_line !~ '\e\[[0-9;]*m'
    return [a:line, 1]
  endif

  return [a:line, vimshell#terminal#get_col(
        \ get(s:virtual.lines, a:line, getline(a:line)), -1, -1, a:col, 1)]
endfunction"}}}
function! s:set_screen_string(line, col, string) abort "{{{
  let [line, col] = s:get_real_pos(a:line, a:col)
  call s:set_screen_pos(line, col)

  let len = strwidth(a:string)
  let s:virtual.lines[line] =
        \ (col > 1 ? s:virtual.lines[line][: col-1] : '')
        \ . a:string
        \ . s:virtual.lines[line][col+len :]
  let current_line = s:virtual.lines[line]

  let s:virtual.col =
        \ vimshell#terminal#get_col(current_line, s:virtual.col, col, col+len, 1)
  if g:vimshell_enable_debug
    echomsg 'current_line = ' . string(current_line)
    echomsg 'current_line[col:] = ' . string(current_line[col :])
    echomsg '[old_virt_col, real_col, new_virt_col, string] = ' .
          \ string([a:col, col, s:virtual.col, a:string])
  endif
endfunction"}}}
function! s:set_screen_pos(line, col) abort "{{{
  if a:line == ''
    return
  endif

  if !has_key(s:virtual.lines, a:line)
    let s:virtual.lines[a:line] = ''
  endif
  if a:col > len(s:virtual.lines[a:line])
    let s:virtual.lines[a:line] .=
          \ repeat(' ', a:col - len(s:virtual.lines[a:line]))
  endif
endfunction"}}}
function! vimshell#terminal#get_col(line, start_virtual, start_real, max_col, is_virtual) abort "{{{
  " is_virtual -> a:col : real col.
  " not -> a:col : virtual col.
  let virtual_col = a:start_virtual < 0 ? 1 : a:start_virtual
  let real_col = a:start_real < 0 ? 0 : a:start_virtual

  let current_line = a:line

  if current_line !~ '\e\[[0-9;]*m'
    " Optimized.
    for c in split(current_line[: a:max_col*3], '\zs')
      let real_col += len(c)
      let virtual_col += strwidth(c)

      let check_col = a:is_virtual ? real_col : virtual_col
      if check_col > a:max_col
        break
      endif
    endfor
  else
    let skip_cnt = 0
    for c in split(current_line[real_col :], '\zs')
      if skip_cnt > 0
        let skip_cnt -= 1
        continue
      endif

      if c == "\<ESC>"
            \ && current_line[real_col :] =~ '^\e\[[0-9;]*m'
        " Skip.
        let sequence = matchstr(current_line,
              \ '^\e\[[0-9;]*m', real_col)
        let skip_cnt = len(sequence)-1
        let real_col += len(sequence)
      else
        let real_col += len(c)
        let virtual_col += strwidth(c)
      endif

      let check_col = a:is_virtual ? real_col : virtual_col
      if check_col > a:max_col
        break
      endif
    endfor
  endif

  return (a:is_virtual ? virtual_col : real_col)
endfunction"}}}

" Escape sequence functions.
let s:escape = {}
function! s:escape.ignore(matchstr) abort "{{{
endfunction"}}}

" Color table. "{{{
let s:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
let s:grey_table = [
      \ 0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E,
      \ 0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E,
      \ 0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
      \]
let s:highlight_table = {
      \ '0' : ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE',
      \ '1' : ' cterm=BOLD gui=BOLD',
      \ '3' : ' cterm=ITALIC gui=ITALIC',
      \ '4' : ' cterm=UNDERLINE gui=UNDERLINE',
      \ '7' : ' cterm=REVERSE gui=REVERSE',
      \ '8' : ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000',
      \ '9' : ' gui=UNDERCURL',
      \ '21' : ' cterm=UNDERLINE gui=UNDERLINE',
      \ '22' : ' gui=NONE',
      \ '23' : ' gui=NONE',
      \ '24' : ' gui=NONE',
      \ '25' : ' gui=NONE',
      \ '27' : ' gui=NONE',
      \ '28' : ' ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE',
      \ '29' : ' gui=NONE',
      \ '39' : ' ctermfg=NONE guifg=NONE',
      \ '49' : ' ctermbg=NONE guibg=NONE',
      \}"}}}
function! s:escape.highlight(matchstr) abort "{{{
  if g:vimshell_disable_escape_highlight
        \ || (b:interactive.type == 'interactive' &&
        \     get(g:vimshell_interactive_monochrome_commands,
        \         b:interactive.command, 0))
        \ || b:interactive.terminal.is_error
    return
  endif

  call s:output_string("\<ESC>" . a:matchstr)

  " Check cached highlight.
  if a:matchstr =~ '^\[0\?m$'
        \ || has_key(b:interactive.terminal.syntax_names, a:matchstr)
    return
  endif

  let highlight = ''
  let highlight_list =
        \ split(matchstr(a:matchstr, '^\[\zs[0-9;]\+'), ';', 1)
  let cnt = 0
  if empty(highlight_list)
    " Default.
    let highlight_list = [ 0 ]
  endif
  for color_code in map(highlight_list, 'str2nr(v:val)')
    if has_key(s:highlight_table, color_code) "{{{
      " Use table.
      let highlight .= s:highlight_table[color_code]
    elseif 30 <= color_code && color_code <= 37
      " Foreground color.
      let highlight .= printf(' ctermfg=%d guifg=%s',
            \ color_code - 30, g:vimshell_escape_colors[color_code - 30])
    elseif color_code == 38
      if len(highlight_list) - cnt < 3
        " Error.
        break
      endif

      " Foreground 256 colors.
      let color = highlight_list[cnt + 2]
      if color >= 232
        " Grey scale.
        let gcolor = s:grey_table[(color - 232)]
        let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x',
              \ color, gcolor, gcolor, gcolor)
      elseif color >= 16
        " RGB.
        let gcolor = color - 16
        let red = s:color_table[gcolor / 36]
        let green = s:color_table[(gcolor % 36) / 6]
        let blue = s:color_table[gcolor % 6]

        let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x',
              \ color, red, green, blue)
      else
        let highlight .= printf(' ctermfg=%d guifg=%s',
              \ color, g:vimshell_escape_colors[color])
      endif
      break
    elseif 40 <= color_code && color_code <= 47
      " Background color.
      let highlight .= printf(' ctermbg=%d guibg=%s',
            \ color_code - 40, g:vimshell_escape_colors[color_code - 40])
    elseif color_code == 48
      if len(highlight_list) - cnt < 3
        " Error.
        break
      endif

      " Background 256 colors.
      let color = highlight_list[cnt + 2]
      if color >= 232
        " Grey scale.
        let gcolor = s:grey_table[(color - 232)]
        let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x',
              \ color, gcolor, gcolor, gcolor)
      elseif color >= 16
        " RGB.
        let gcolor = color - 16
        let red = s:color_table[gcolor / 36]
        let green = s:color_table[(gcolor % 36) / 6]
        let blue = s:color_table[gcolor % 6]

        let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x',
              \ color, red, green, blue)
      else
        let highlight .= printf(' ctermbg=%d guibg=%s',
              \ color, g:vimshell_escape_colors[color])
      endif
      break
    elseif 90 <= color_code && color_code <= 97
      " Foreground color(high intensity).
      let highlight .= printf(' ctermfg=%d guifg=%s',
            \ color_code - 82, g:vimshell_escape_colors[color_code - 82])
    elseif 100 <= color_code && color_code <= 107
      " Background color(high intensity).
      let highlight .= printf(' ctermbg=%d guibg=%s',
            \ color_code - 92, g:vimshell_escape_colors[color_code - 92])
    endif"}}}

    let cnt += 1
  endfor

  if highlight == ''
    return
  endif

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  let col += 1
  let syntax_name = 'EscapeSequenceAt_' . bufnr('%')
        \ . '_' . line . '_' . col
  let syntax_command = printf('start=+\e\%s+ end=+\ze\e[\[0*m]\|$+ ' .
        \ 'contains=vimshellEscapeSequenceConceal oneline', a:matchstr)

  execute 'syntax region' syntax_name syntax_command
  execute 'highlight' syntax_name highlight

  let terminal = b:interactive.terminal
  let terminal.syntax_names[a:matchstr] = syntax_name
  let terminal.syntax_commands[syntax_name] = syntax_command
  let terminal.syntax_highlights[syntax_name] = highlight

  " Note: When use concealed text, wrapped text is wrong...
  setlocal nowrap
endfunction"}}}
function! s:escape.move_cursor(matchstr) abort "{{{
  let params = matchstr(a:matchstr, '[0-9;]\+')
  if params == ''
    let args = [1, 1]
  else
    let args = split(params, ';', 1)
  endif

  let s:virtual.line = get(args, 0, 1)
  let s:virtual.col = get(args, 1, 1)
  if s:virtual.line !~ '^\d\+$' || s:virtual.col !~ '^\d\+$'
    call vimshell#echo_error(
          \ 'Move cursor escape sequence format error: str = "'
          \ . a:matchstr . '"')
    return
  endif

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)
endfunction"}}}
function! s:escape.move_cursor_column(matchstr) abort "{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let s:virtual.col = n

  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)
endfunction"}}}
function! s:escape.setup_scrolling_region(matchstr) abort "{{{
  let args = split(matchstr(a:matchstr, '[0-9;]\+'), ';', 1)

  let top = empty(args) ? 0 : args[0]
  let bottom = empty(args) ? 0 : args[1]

  if top == 1
    if (vimshell#util#is_windows() && bottom == 25)
          \|| (!vimshell#util#is_windows() && bottom == b:interactive.height)
      " Clear scrolling region.
      let [top, bottom] = [0, 0]
    endif
  endif

  let b:interactive.terminal.region_top = top
  let b:interactive.terminal.region_bottom = bottom
endfunction"}}}
function! s:escape.clear_line(matchstr) abort "{{{
  let [line, col] = s:get_real_pos(s:virtual.line, s:virtual.col)
  call s:set_screen_pos(line, col)

  let param = matchstr(a:matchstr, '\d\+')
  if param == '' || param == '0'
    " Clear right line.
    let s:virtual.lines[line] = (col <= 0) ? '' : s:virtual.lines[line][ : col - 1]
  elseif param == '1'
    " Clear left line.
    let s:virtual.lines[line] = s:virtual.lines[line][col :]
    let s:virtual.col = 1
  elseif param == '2'
    " Clear whole line.
    let s:virtual.lines[line] = ''
    let s:virtual.col = 1
  endif
endfunction"}}}
function! s:escape.clear_screen(matchstr) abort "{{{
  let param = matchstr(a:matchstr, '\d\+')
  if param == '' || param == '0'
    " Clear screen from cursor down.
    call s:escape.clear_line(0)
    for linenr in filter(keys(s:virtual.lines), 'v:val > s:virtual.line')
      " Clear line.
      let s:virtual.lines[linenr] = ''
    endfor
  elseif param == '1'
    " Clear screen from cursor up.
    call s:escape.clear_line(1)
    for linenr in filter(keys(s:virtual.lines), 'v:val < s:virtual.line')
      " Clear line.
      let s:virtual.lines[linenr] = ''
    endfor
  elseif param == '2'
    " Clear entire screen.
    let reg = @x
    1,$ delete x
    let @x = reg

    let s:virtual.lines = {}
    let s:virtual.line = 1
    let s:virtual.col = 1

    call vimshell#terminal#clear_highlight()
  endif
endfunction"}}}
function! s:escape.move_up(matchstr) abort "{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  if b:interactive.terminal.region_top <= s:virtual.line
        \ && s:virtual.line <= b:interactive.terminal.region_bottom
    " Scroll up n lines.
    call s:scroll_up(n)
  else
    let s:virtual.line -= n
    if s:virtual.line < 1
      let s:virtual.line = 1
    endif
  endif
endfunction"}}}
function! s:escape.move_down(matchstr) abort "{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  if b:interactive.terminal.region_top <= s:virtual.line
        \ && s:virtual.line <= b:interactive.terminal.region_bottom
    " Scroll down n lines.
    call s:scroll_down(n)
  else
    let s:virtual.line += n
  endif
endfunction"}}}
function! s:escape.move_right(matchstr) abort "{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let s:virtual.col += n
endfunction"}}}
function! s:escape.move_left(matchstr) abort "{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  let s:virtual.col -= n
  if s:virtual.col < 1
    let s:virtual.col = 1
  endif
endfunction"}}}
function! s:escape.move_down_head1(matchstr) abort "{{{
  call s:control.newline()
endfunction"}}}
function! s:escape.move_down_head(matchstr) abort "{{{
  call s:scroll_down(a:matchstr)
  let s:virtual.col = 1
endfunction"}}}
function! s:escape.move_up_head(matchstr) abort "{{{
  let param = matchstr(a:matchstr, '\d\+')
  if param != '0'
    call s:scroll_up(a:matchstr)
  endif
  let s:virtual.col = 1
endfunction"}}}
function! s:escape.scroll_up1(matchstr) abort "{{{
  call s:scroll_up(1)
endfunction"}}}
function! s:escape.scroll_down1(matchstr) abort "{{{
  call s:scroll_down(1)
endfunction"}}}
function! s:escape.move_col(matchstr) abort "{{{
  let num = matchstr(a:matchstr, '\d\+')
  let s:virtual.col = num
  if s:virtual.col < 1
    let s:virtual.col = 1
  endif
endfunction"}}}
function! s:escape.save_pos(matchstr) abort "{{{
  let b:interactive.terminal.save_pos = [s:virtual.line, s:virtual.col]
endfunction"}}}
function! s:escape.restore_pos(matchstr) abort "{{{
  let [s:virtual.line, s:virtual.col] = b:interactive.terminal.save_pos
endfunction"}}}
function! s:escape.change_title(matchstr) abort "{{{
  let title = matchstr(a:matchstr, '^k\zs.\{-}\ze\e\\')
  if empty(title)
    let title = matchstr(a:matchstr, '^][02];\zs.\{-}\ze'."\<C-g>")
  endif

  let &titlestring = title
  let b:interactive.terminal.titlestring = title
endfunction"}}}
function! s:escape.print_control_sequence(matchstr) abort "{{{
  call s:output_string("\<ESC>")
endfunction"}}}
function! s:escape.change_cursor_shape(matchstr) abort "{{{
  if !exists('+guicursor') || b:interactive.type !=# 'terminal'
    return
  endif

  let arg = matchstr(a:matchstr, '\d\+')

  if arg == 0 || arg == 1
    set guicursor=i:block-Cursor/lCursor
  elseif arg == 2
    set guicursor=i:block-Cursor/lCursor-blinkon0
  elseif arg == 3
    set guicursor=i:hor20-Cursor/lCursor
  elseif arg == 4
    set guicursor=i:hor20-Cursor/lCursor-blinkon0
  endif
endfunction"}}}
function! s:escape.change_character_set(matchstr) abort "{{{
  if a:matchstr =~ '^[()]0'
    " Line drawing set.
    if a:matchstr =~ '^('
      let b:interactive.terminal.standard_character_set = 'Line Drawing'
    else
      let b:interactive.terminal.alternate_character_set = 'Line Drawing'
    endif
  endif
endfunction"}}}
function! s:escape.reset(matchstr) abort "{{{
  call vimshell#terminal#init()
endfunction"}}}
function! s:escape.delete_chars(matchstr) abort "{{{
  let n = matchstr(a:matchstr, '\d\+')
  if n == ''
    let n = 1
  endif

  call s:escape.move_left(n)
  call s:output_string(repeat(' ', n))
endfunction"}}}

" Control sequence functions.
let s:control = {}
function! s:control.ignore() abort "{{{
endfunction"}}}
function! s:control.newline() abort "{{{
  let s:virtual.col = 1

  if b:interactive.type !=# 'terminal'
    " New line.
    call append(s:virtual.line, '')
  endif

  call s:escape.move_down(1)
endfunction"}}}
function! s:control.delete_backword_char() abort "{{{
  if s:virtual.line == b:interactive.echoback_linenr
    return
  endif

  if s:virtual.col == 1
    " Wrap above line.
    if s:virtual.line > 1
      let s:virtual.line -= 1
    endif

    if !has_key(s:virtual.lines, s:virtual.line)
      let s:virtual.lines[s:virtual.line] = getline(s:virtual.line)
    endif

    let s:virtual.col = s:get_virtual_col(
          \ s:virtual.line, len(s:virtual.lines[s:virtual.line]))[1]
    return
  endif

  call s:escape.move_left(1)
endfunction"}}}
function! s:control.delete_multi_backword_char() abort "{{{
  if s:virtual.line == b:interactive.echoback_linenr
    return
  endif

  if s:virtual.col == 1
    " Wrap above line.
    if s:virtual.line > 1
      let s:virtual.line -= 1
    endif

    if !has_key(s:virtual.lines, s:virtual.line)
      let s:virtual.lines[s:virtual.line] = getline(s:virtual.line)
    endif

    let s:virtual.col = len(s:virtual.lines[s:virtual.line])
    return
  endif

  call s:escape.move_left(2)
endfunction"}}}
function! s:control.carriage_return() abort "{{{
  let s:virtual.col = 1
endfunction"}}}
function! s:control.bell() abort "{{{
  echo 'Ring!'
endfunction"}}}
function! s:control.shift_in() abort "{{{
  let b:interactive.terminal.current_character_set = b:interactive.terminal.standard_character_set
endfunction"}}}
function! s:control.shift_out() abort "{{{
  let b:interactive.terminal.current_character_set = b:interactive.terminal.alternate_character_set
endfunction"}}}

let s:drawing_character_table = {
      \ 'j' : '+', 'k' : '+', 'l' : '+', 'm' : '+', 'n' : '+',
      \ 'o' : '-', 'p' : '-', 'q' : '-',
      \ 'r' : '_', 's' : '_',
      \ 't' : '+', 'u' : '+', 'v' : '+', 'w' : '+',
      \ 'x' : '|', 'a' : '#', '+' : '^', ',' : '<',
      \ '.' : 'v', 'I' : '0', '-' : '>', '''' : '*',
      \ 'h' : '#', '~' : 'O',
      \ }

" escape sequence list. {{{
" pattern: function
let s:escape_sequence_csi = {
      \ 'l' : s:escape.ignore,
      \ 'h' : s:escape.ignore,
      \
      \ 'm' : s:escape.highlight,
      \ 'r' : s:escape.setup_scrolling_region,
      \ 'A' : s:escape.move_up,
      \ 'B' : s:escape.move_down,
      \ 'C' : s:escape.move_right,
      \ 'D' : s:escape.move_left,
      \ 'E' : s:escape.move_down_head,
      \ 'F' : s:escape.move_up_head,
      \ 'G' : s:escape.move_col,
      \ 'H' : s:escape.move_cursor,
      \ 'f' : s:escape.move_cursor,
      \ 'J' : s:escape.clear_screen,
      \ 'K' : s:escape.clear_line,
      \ 'P' : s:escape.delete_chars,
      \
      \ 'g' : s:escape.ignore,
      \ 'c' : s:escape.ignore,
      \ 'd' : s:escape.move_cursor_column,
      \ 'y' : s:escape.ignore,
      \ 'q' : s:escape.ignore,
      \}
let s:escape_sequence_match = {
      \ '^\[?\d\+[hl]' : s:escape.ignore,
      \ '^[()][AB012UK]' : s:escape.change_character_set,
      \ '^k.\{-}\e\\' : s:escape.change_title,
      \ '^\][02];.\{-}'."\<C-g>" : s:escape.change_title,
      \ '^#\d' : s:escape.ignore,
      \ '^\dn' : s:escape.ignore,
      \ '^\[?1;\d\+0c' : s:escape.ignore,
      \ '^\d q' : s:escape.change_cursor_shape,
      \ '^\]4;\d\+;rgb:\x\x/\x\x/\x\x\e\\' : s:escape.ignore,
      \}
let s:escape_sequence_simple_char1 = {
      \ 'N' : s:escape.ignore,
      \ 'O' : s:escape.ignore,
      \
      \ '7' : s:escape.save_pos,
      \ '8' : s:escape.restore_pos,
      \ '(' : s:escape.ignore,
      \
      \ 'c' : s:escape.reset,
      \
      \ '<' : s:escape.ignore,
      \ '=' : s:escape.ignore,
      \ '>' : s:escape.ignore,
      \
      \ 'E' : s:escape.move_down_head1,
      \ 'G' : s:escape.ignore,
      \ 'I' : s:escape.ignore,
      \ 'J' : s:escape.ignore,
      \ 'K' : s:escape.ignore,
      \ 'D' : s:escape.scroll_up1,
      \ 'M' : s:escape.scroll_down1,
      \
      \ 'Z' : s:escape.ignore,
      \ '%' : s:escape.ignore,
      \}
let s:escape_sequence_simple_char2 = {
      \ '/Z' : s:escape.ignore,
      \ '%@' : s:escape.ignore,
      \ '%G' : s:escape.ignore,
      \ '%8' : s:escape.ignore,
      \ '#8' : s:escape.ignore,
      \}
"}}}
" control sequence list. {{{
" pattern: function
let s:control_sequence = {
      \ "\<LF>" : s:control.newline,
      \ "\<CR>" : s:control.carriage_return,
      \ "\<C-h>" : s:control.delete_backword_char,
      \ "\<Del>" : s:control.ignore,
      \ "\<C-g>" : s:control.bell,
      \ "\<C-o>" : s:control.shift_in,
      \ "\<C-n>" : s:control.shift_out,
      \ "\<C-a>" : s:control.ignore,
      \ "\<C-b>" : s:control.ignore,
      \}
"}}}

" vim: foldmethod=marker
