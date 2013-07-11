" LaTeX Box latexmk functions

" Options and variables {{{

if !exists('g:LatexBox_latexmk_options')
	let g:LatexBox_latexmk_options = ''
endif
if !exists('g:LatexBox_latexmk_async')
	let g:LatexBox_latexmk_async = 0
endif
if !exists('g:LatexBox_latexmk_preview_continuously')
	let g:LatexBox_latexmk_preview_continuously = 0
endif
if !exists('g:LatexBox_output_type')
	let g:LatexBox_output_type = 'pdf'
endif
if !exists('g:LatexBox_viewer')
	let g:LatexBox_viewer = 'xdg-open'
endif
if !exists('g:LatexBox_autojump')
	let g:LatexBox_autojump = 0
endif
if ! exists('g:LatexBox_quickfix')
	let g:LatexBox_quickfix = 1
endif

" }}}

" Process ID management (used for asynchronous and continuous mode) {{{

" dictionary of latexmk PID's (basename: pid)
if !exists('g:latexmk_running_pids')
	let g:latexmk_running_pids = {}
endif

" Set PID {{{
function! s:LatexmkSetPID(basename, pid)
	let g:latexmk_running_pids[a:basename] = a:pid
endfunction
" }}}

" kill_latexmk_process {{{
function! s:kill_latexmk_process(pid)
	if g:LatexBox_latexmk_async
		" vim-server mode
		let pids = []
		let tmpfile = tempname()
		silent execute '!ps x -o pgid,pid > ' . tmpfile
		for line in readfile(tmpfile)
			let new_pid = matchstr(line, '^\s*' . a:pid . '\s\+\zs\d\+\ze')
			if !empty(new_pid)
				call add(pids, new_pid)
			endif
		endfor
		call delete(tmpfile)
		if !empty(pids)
			silent execute '!kill ' . join(pids)
		endif
	else
		" single background process
		silent execute '!kill ' . a:pid
	endif
	if !has('gui_running')
		redraw!
	endif
endfunction
" }}}

" kill_all_latexmk_processes {{{
function! s:kill_all_latexmk_processes()
	for pid in values(g:latexmk_running_pids)
		call s:kill_latexmk_process(pid)
	endfor
endfunction
" }}}

" }}}

" Setup for vim-server {{{

if g:LatexBox_latexmk_async

	function! s:GetSID()
		return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze.*$')
	endfunction

	function! s:SIDWrap(func)
		return s:SID . a:func
	endfunction

	function! s:LatexmkCallback(basename, status)
		" only remove the pid if not in continuous mode
		if !g:LatexBox_latexmk_preview_continuously
			call remove(g:latexmk_running_pids, a:basename)
			call LatexBox_LatexErrors(a:status, a:basename)
		endif
	endfunction

	let s:SID = s:GetSID()

	if !exists('g:vim_program')

		if match(&shell, '/\(bash\|zsh\)$') >= 0
			let ppid = '$PPID'
		else
			let ppid = '$$'
		endif

		" attempt autodetection of vim executable
		let g:vim_program = ''
		let tmpfile = tempname()
		silent execute '!ps -o command= -p ' . ppid . ' > ' . tmpfile
		for line in readfile(tmpfile)
			let line = matchstr(line, '^\S\+\>')
			if !empty(line) && executable(line)
				let g:vim_program = line . ' -g'
				break
			endif
		endfor
		call delete(tmpfile)

		if empty(g:vim_program)
			if has('gui_macvim')
				let g:vim_program = '/Applications/MacVim.app/Contents/MacOS/Vim -g'
			else
				let g:vim_program = v:progname
			endif
		endif
	endif

endif

" }}}

" Latexmk {{{
function! LatexBox_Latexmk(force)

	if g:LatexBox_latexmk_async && empty(v:servername)
		echoerr "cannot run latexmk in background without a VIM server"
		echoerr "set g:LatexBox_latexmk_async to 0 to change compiling mode"
		return
	endif

	let basename = LatexBox_GetTexBasename(1)

	if g:LatexBox_latexmk_async
		" compile in the background using vim-server

		if has_key(g:latexmk_running_pids, basename)
			echomsg "latexmk is already running for `" . fnamemodify(basename, ':t') . "'"
			return
		endif

		let callsetpid = s:SIDWrap('LatexmkSetPID')
		let callback = s:SIDWrap('LatexmkCallback')

		let l:options = '-' . g:LatexBox_output_type . ' -quiet ' . g:LatexBox_latexmk_options
		if a:force
			let l:options .= ' -g'
		endif
		if g:LatexBox_latexmk_preview_continuously
			let l:options .= ' -pvc'
		endif
		let l:options .= " -e '$pdflatex =~ s/ / -file-line-error /'"
		let l:options .= " -e '$latex =~ s/ / -file-line-error /'"

		" callback to set the pid
		let vimsetpid = g:vim_program . ' --servername ' . v:servername . ' --remote-expr ' .
					\ shellescape(callsetpid) . '\(\"' . fnameescape(basename) . '\",$$\)'

		" wrap width in log file
		let max_print_line = 2000

		" set environment
		if match(&shell, '/tcsh$') >= 0
			let l:env = 'setenv max_print_line ' . max_print_line . '; '
		else
			let l:env = 'max_print_line=' . max_print_line
		endif

		" latexmk command
		let mainfile = fnamemodify(LatexBox_GetMainTexFile(), ':t')
		let cmd = 'cd ' . shellescape(LatexBox_GetTexRoot()) . ' ; ' . l:env .
					\ ' latexmk ' . l:options	. ' ' . mainfile

		" callback after latexmk is finished
		let vimcmd = g:vim_program . ' --servername ' . v:servername . ' --remote-expr ' .
					\ shellescape(callback) . '\(\"' . fnameescape(basename) . '\",$?\)'

		silent execute '! ( ' . vimsetpid . ' ; ( ' . cmd . ' ) ; ' . vimcmd . ' ) >&/dev/null &'
		if !has("gui_running")
			redraw!
		endif

	else
		" compile directly

		if g:LatexBox_latexmk_preview_continuously && has_key(g:latexmk_running_pids, basename)
			echomsg "latexmk is already running for `" . fnamemodify(basename, ':t') . "'"
			return
		endif

		let texroot = LatexBox_GetTexRoot()
		let mainfile = fnamemodify(LatexBox_GetMainTexFile(), ':t')
		let l:cmd = 'cd ' . shellescape(texroot) . ' ;'
		let l:cmd .= 'latexmk -' . g:LatexBox_output_type . ' '
		if a:force
			let l:cmd .= ' -g'
		endif
		if g:LatexBox_latexmk_preview_continuously
			let l:cmd .= ' -pvc'
		endif
		let l:cmd .= g:LatexBox_latexmk_options
		let l:cmd .= ' -silent'
		let l:cmd .= " -e '$pdflatex =~ s/ / -file-line-error /'"
		let l:cmd .= " -e '$latex =~ s/ / -file-line-error /'"
		let l:cmd .= ' ' . shellescape(mainfile)

		if g:LatexBox_latexmk_preview_continuously
			let l:cmd .= '>/dev/null &'
		else
			let l:cmd .= '>/dev/null'
		endif

		" Execute command
		echo 'Compiling to ' . g:LatexBox_output_type . '...'
		let l:cmd_output = system(l:cmd)
		if !has('gui_running')
			redraw!
		endif

		if !g:LatexBox_latexmk_preview_continuously
			" check for errors
			call LatexBox_LatexErrors(v:shell_error)
			if v:shell_error > 0
				echomsg "Error (latexmk exited with status " . v:shell_error . ")."
			elseif match(l:cmd_output, 'Rule') > -1
				echomsg "Success!"
			else
				echomsg "No file change detected. Skipping."
			endif
		else
			" Save PID in order to be able to kill the process when wanted.
			let pid = substitute(system('pgrep -f ' . mainfile),'\D','','')
			let g:latexmk_running_pids[basename] = pid
		endif

	endif

endfunction
" }}}

" LatexmkClean {{{
function! LatexBox_LatexmkClean(cleanall)
	let basename = LatexBox_GetTexBasename(1)
	if has_key(g:latexmk_running_pids, basename)
		echomsg "don't clean when latexmk is running"
		return
	endif

	let cmd = '! cd ' . shellescape(LatexBox_GetTexRoot()) . ';'
	if a:cleanall
		let cmd .= 'latexmk -C '
	else
		let cmd .= 'latexmk -c '
	endif
	let cmd .= shellescape(LatexBox_GetMainTexFile())
	let cmd .= '>&/dev/null'

	silent execute cmd
	if !has('gui_running')
		redraw!
	endif

	echomsg "latexmk clean finished"
endfunction
" }}}

" LatexErrors {{{
function! LatexBox_LatexErrors(status, ...)
	if a:0 >= 1
		let log = a:1 . '.log'
	else
		let log = LatexBox_GetLogFile()
	endif

	cclose

	" set cwd to expand error file correctly
	let l:cwd = fnamemodify(getcwd(), ':p')
	execute 'lcd ' . LatexBox_GetTexRoot()
	try
		if g:LatexBox_autojump
			execute 'cfile ' . fnameescape(log)
		else
			execute 'cgetfile ' . fnameescape(log)
		endif
	finally
		" restore cwd
		execute 'lcd ' . l:cwd
	endtry

	" always open window if started by LatexErrors command
	if a:status < 0
		botright copen
	" otherwise only when an error/warning is detected
	elseif g:LatexBox_quickfix
		botright cw
		if g:LatexBox_quickfix==2
			wincmd p
		endif
	endif

endfunction
" }}}

" LatexmkStatus {{{
function! LatexBox_LatexmkStatus(detailed)

	if a:detailed
		if empty(g:latexmk_running_pids)
			echo "latexmk is not running"
		else
			let plist = ""
			for [basename, pid] in items(g:latexmk_running_pids)
				if !empty(plist)
					let plist .= '; '
				endif
				let plist .= fnamemodify(basename, ':t') . ':' . pid
			endfor
			echo "latexmk is running (" . plist . ")"
		endif
	else
		let basename = LatexBox_GetTexBasename(1)
		if has_key(g:latexmk_running_pids, basename)
			echo "latexmk is running"
		else
			echo "latexmk is not running"
		endif
	endif

endfunction
" }}}

" LatexmkStop {{{
function! LatexBox_LatexmkStop(silent)
	let basename = LatexBox_GetTexBasename(1)
	if has_key(g:latexmk_running_pids, basename)
		call s:kill_latexmk_process(g:latexmk_running_pids[basename])
		call remove(g:latexmk_running_pids, basename)
		if !a:silent
			echomsg "latexmk stopped for `" . fnamemodify(basename, ':t') . "'"
		endif
	else
		if !a:silent
			echoerr "latexmk is not running for `" . fnamemodify(basename, ':t') . "'"
		endif
	endif
endfunction
" }}}

" Commands {{{

command! -bang	Latexmk			call LatexBox_Latexmk(<q-bang> == "!")
command! -bang	LatexmkClean	call LatexBox_LatexmkClean(<q-bang> == "!")
command! -bang	LatexmkStatus	call LatexBox_LatexmkStatus(<q-bang> == "!")
command! LatexmkStop			call LatexBox_LatexmkStop(0)
command! LatexErrors			call LatexBox_LatexErrors(-1)

if g:LatexBox_latexmk_async || g:LatexBox_latexmk_preview_continuously
	autocmd BufUnload <buffer> 	call LatexBox_LatexmkStop(1)
	autocmd VimLeave * 			call <SID>kill_all_latexmk_processes()
endif

" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
