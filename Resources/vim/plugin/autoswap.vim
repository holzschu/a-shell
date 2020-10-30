" Vim global plugin for automating response to swapfiles
" Maintainer: Gioele Barabucci
" Author:     Damian Conway
" License:    This is free software released into the public domain (CC0 license).

"#############################################################
"##                                                         ##
"##  Note that this plugin only works if your Vim           ##
"##  configuration includes:                                ##
"##                                                         ##
"##     set title titlestring=                              ##
"##                                                         ##
"##  On MacOS this plugin only works fully for Vim sessions ##
"##  running in Apple Terminal or iTerm2. Other terminals   ##
"##  and GUI Vims are partially supported, but detecting    ##
"##  and switching to the active window will not work.      ##
"##                                                         ##
"##  On Linux this plugin requires the external program     ##
"##  wmctrl, packaged for most distributions.               ##
"##                                                         ##
"##  See below for the two functions that would have to be  ##
"##  rewritten to port this plugin to other OS's.           ##
"##                                                         ##
"#############################################################


" If already loaded, we're done...
if exists("loaded_autoswap")
	finish
endif
let loaded_autoswap = 1

" By default we don't try to detect tmux
if !exists("g:autoswap_detect_tmux")
	let g:autoswap_detect_tmux = 0
endif

" Preserve external compatibility options, then enable full vim compatibility...
let s:save_cpo = &cpo
set cpo&vim

" Invoke the behaviour whenever a swapfile is detected...
"
augroup AutoSwap
	autocmd!
	autocmd SwapExists *  call AS_HandleSwapfile(expand('<afile>:p'), v:swapname)
augroup END

" The automatic behaviour...
"
function! AS_HandleSwapfile (filename, swapname)

	" Is file already open in another Vim session in some other window?
	let active_window = AS_DetectActiveWindow(a:filename, a:swapname)

	" If so, go there instead and terminate this attempt to open the file...
	if (strlen(active_window) > 0)
		call AS_DelayedMsg('Switched to existing session in another window')
		call AS_SwitchToActiveWindow(active_window)
		let v:swapchoice = 'q'

	" Otherwise, if swapfile is older than file itself, just get rid of it...
	elseif getftime(v:swapname) < getftime(a:filename)
		call AS_DelayedMsg('Old swapfile detected... and deleted')
		call delete(v:swapname)
		let v:swapchoice = 'e'

	" Otherwise, open file read-only...
	else
		call AS_DelayedMsg('Swapfile detected, opening read-only')
		let v:swapchoice = 'o'
	endif
endfunction


" Print a message after the autocommand completes
" (so you can see it, but don't have to hit <ENTER> to continue)...
"
function! AS_DelayedMsg (msg)
	" A sneaky way of injecting a message when swapping into the new buffer...
	augroup AutoSwap_Msg
		autocmd!
		" Print the message on finally entering the buffer...
		autocmd BufWinEnter *  echohl WarningMsg
		exec 'autocmd BufWinEnter *  echon "\r'.printf("%-60s", a:msg).'"'
		autocmd BufWinEnter *  echohl NONE

		" And then remove these autocmds, so it's a "one-shot" deal...
		autocmd BufWinEnter *  augroup AutoSwap_Msg
		autocmd BufWinEnter *  autocmd!
		autocmd BufWinEnter *  augroup END
	augroup END
endfunction


"#################################################################
"##                                                             ##
"##  To port this plugin to other operating systems             ##
"##                                                             ##
"##    1. Rewrite the Detect and the Switch function            ##
"##    2. Add a new elseif case to the list of OS               ##
"##                                                             ##
"#################################################################

function! AS_RunningTmux ()
	if $TMUX != ""
		return 1
	endif
	return 0
endfunction

" Return an identifier for a terminal window already editing the named file
" (Should either return a string identifying the active window,
"  or else return an empty string to indicate "no active window")...
"
function! AS_DetectActiveWindow (filename, swapname)
	if g:autoswap_detect_tmux && AS_RunningTmux()
		let active_window = AS_DetectActiveWindow_Tmux(a:swapname)
	elseif has('macunix')
		let active_window = AS_DetectActiveWindow_Mac(a:filename)
	elseif has('unix')
		let active_window = AS_DetectActiveWindow_Linux(a:filename)
	endif
	return active_window
endfunction

" TMUX: Detection function for tmux, uses tmux
function! AS_DetectActiveWindow_Tmux (swapname)
	let pid = systemlist('fuser '.a:swapname.' 2>/dev/null | grep -E -o "[0-9]+"')
	if (len(pid) == 0)
		return ''
	endif
	let tty = systemlist('ps -o "tt=" '.pid[0].' 2>/dev/null')
	if (len(tty) == 0)
		return ''
	endif
	let tty[0] = substitute(tty[0], '\s\+$', '', '')
	" The output of `ps -o tt` and `tmux-list panes` varies from
	" system to system.
	" * Linux: `pts/1`, `/dev/pts/1`
	" * FreeBSD: `1`, `/dev/vc/1`
	" * Darwin/macOS: `s001`, `/dev/ttys001`
	let window = systemlist('tmux list-panes -aF "#{pane_tty} #{window_index} #{pane_index}" | grep -F "'.tty[0].' " 2>/dev/null')
	if (len(window) == 0)
		return ''
	endif
	return window[0]
endfunction

" LINUX: Detection function for Linux, uses mwctrl
function! AS_DetectActiveWindow_Linux (filename)
	let shortname = fnamemodify(a:filename,":t")
	let find_win_cmd = 'wmctrl -l | grep -i " '.shortname.' .*vim" | tail -n1 | cut -d" " -f1'
	let active_window = system(find_win_cmd)
	return (active_window =~ '0x' ? active_window : "")
endfunction

" MAC: Detection function for Mac OSX, uses osascript
function! AS_DetectActiveWindow_Mac (filename)
	let shortname = fnamemodify(a:filename,":t")
	if ($TERM_PROGRAM == 'Apple_Terminal')
		let find_win_cmd = 'osascript -e ''tell application "Terminal" to get the id of every window whose (name begins with "'.shortname.' " and name contains "VIM")'''
	elseif ($TERM_PROGRAM == 'iTerm.app')
		let find_win_cmd = 'osascript -e ''tell application "iTerm2" to get the index of every window whose (name contains "'.shortname.' " and name contains "VIM")'''
	else
		return ''
	endif
	let active_window = system(find_win_cmd)
	let active_window = substitute(active_window, '^\d\+\zs\_.*', '', '')
	return (active_window =~ '\d\+' ? active_window : "")
endfunction


" Switch to terminal window specified...
"
function! AS_SwitchToActiveWindow (active_window)
	if g:autoswap_detect_tmux && AS_RunningTmux()
		call AS_SwitchToActiveWindow_Tmux(a:active_window)
	elseif has('macunix')
		call AS_SwitchToActiveWindow_Mac(a:active_window)
	elseif has('unix')
		call AS_SwitchToActiveWindow_Linux(a:active_window)
	endif
endfunction

" TMUX: Switch function for Tmux
function! AS_SwitchToActiveWindow_Tmux (active_window)
	let pane_info = split(a:active_window)
	call system('tmux select-window -t '.pane_info[1].'; tmux select-pane -t '.pane_info[2])
endfunction

" LINUX: Switch function for Linux, uses wmctrl
function! AS_SwitchToActiveWindow_Linux (active_window)
	call system('wmctrl -i -a "'.a:active_window.'"')
endfunction

" MAC: Switch function for Mac, uses osascript
function! AS_SwitchToActiveWindow_Mac (active_window)
	if ($TERM_PROGRAM == 'Apple_Terminal')
		call system('osascript -e ''tell application "Terminal" to set frontmost of window id '.a:active_window.' to true''')
	elseif ($TERM_PROGRAM == 'iTerm.app')
		let switch_win_cmd = 'osascript -e ''tell application "iTerm"''
					\ -e ''repeat with mywindow in windows''
					\ -e ''   if index of mywindow is ' .a:active_window. '''
					\ -e ''     select mywindow''
					\ -e ''   return''
					\ -e ''   end if''
					\ -e '' end repeat''
					\ -e ''end tell'''
		call system(switch_win_cmd)
	endif
endfunction

" Restore previous external compatibility options
let &cpo = s:save_cpo

" vim: noexpandtab tabstop=4 softtabstop=4 shiftwidth=4
