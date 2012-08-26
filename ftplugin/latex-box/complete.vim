" LaTeX Box completion

" <SID> Wrap {{{
function! s:GetSID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze.*$')
endfunction
let s:SID = s:GetSID()
function! s:SIDWrap(func)
	return s:SID . a:func
endfunction
" }}}


" Omni Completion {{{

let s:completion_type = ''

function! LatexBox_Complete(findstart, base)
	if a:findstart
		" return the starting position of the word
		let line = getline('.')
		let pos = col('.') - 1
		while pos > 0 && line[pos - 1] !~ '\\\|{'
			let pos -= 1
		endwhile

		let line_start = line[:pos-1]
		if line_start =~ '\C\\begin\_\s*{$'
			let s:completion_type = 'begin'
		elseif line_start =~ '\C\\end\_\s*{$'
			let s:completion_type = 'end'
		elseif line_start =~ g:LatexBox_ref_pattern . '$'
			let s:completion_type = 'ref'
		elseif line_start =~ g:LatexBox_cite_pattern . '$'
			let s:completion_type = 'bib'
			" check for multiple citations
			let pos = col('.') - 1
			while pos > 0 && line[pos - 1] !~ '{\|,'
				let pos -= 1
			endwhile
		else
			let s:completion_type = 'command'
			if line[pos - 1] == '\'
				let pos -= 1
			endif
		endif
		return pos
	else
		" return suggestions in an array
		let suggestions = []

		if s:completion_type == 'begin'
			" suggest known environments
			for entry in g:LatexBox_completion_environments
				if entry.word =~ '^' . escape(a:base, '\')
					if g:LatexBox_completion_close_braces && !s:NextCharsMatch('^}')
						" add trailing '}'
						let entry = copy(entry)
						let entry.abbr = entry.word
						let entry.word = entry.word . '}'
					endif
					call add(suggestions, entry)
				endif
			endfor
		elseif s:completion_type == 'end'
			" suggest known environments
			let env = LatexBox_GetCurrentEnvironment()
			if env != ''
				if g:LatexBox_completion_close_braces && !s:NextCharsMatch('^\s*[,}]')
					call add(suggestions, {'word': env . '}', 'abbr': env})
				else
					call add(suggestions, env)
				endif
			endif
		elseif s:completion_type == 'command'
			" suggest known commands
			for entry in g:LatexBox_completion_commands
				if entry.word =~ '^' . escape(a:base, '\')
					" do not display trailing '{'
					if entry.word =~ '{'
						let entry.abbr = entry.word[0:-2]
					endif
					call add(suggestions, entry)
				endif
			endfor
		elseif s:completion_type == 'ref'
			let suggestions = s:CompleteLabels(a:base)
		elseif s:completion_type == 'bib'
			" suggest BibTeX entries
			let suggestions = LatexBox_BibComplete(a:base)
		endif
		if !has('gui_running')
			redraw!
		endif
		return suggestions
	endif
endfunction
" }}}


" BibTeX search {{{

" find the \bibliography{...} commands
" the optional argument is the file name to be searched
function! LatexBox_kpsewhich(file)
	let old_dir = getcwd()
	execute 'lcd ' . fnameescape(LatexBox_GetTexRoot())
	redir => out
	silent execute '!kpsewhich ' . a:file
	redir END

	let out = split(out, "\<NL>")[-1]
	let out = substitute(out, '\r', '', 'g')
	let out = glob(fnamemodify(out, ':p'), 1)
	
	execute 'lcd ' . fnameescape(old_dir)

	return out
endfunction

function! s:FindBibData(...)

	if a:0 == 0
		let file = LatexBox_GetMainTexFile()
	else
		let file = a:1
	endif

	if empty(glob(file, 1))
		return ''
	endif

	let bibliography_cmds = [ '\\bibliography', '\\addbibresource', '\\addglobalbib', '\\addsectionbib' ]

	let lines = readfile(file)

	let bibdata_list = []

	for cmd in bibliography_cmds
		let bibdata_list +=
				\ map(filter(copy(lines), 'v:val =~ ''\C' . cmd . '\s*{[^}]\+}'''),
				\ 'matchstr(v:val, ''\C' . cmd . '\s*{\zs[^}]\+\ze}'')')
	endfor

	let bibdata_list +=
				\ map(filter(copy(lines), 'v:val =~ ''\C\\\%(input\|include\)\s*{[^}]\+}'''),
				\ 's:FindBibData(LatexBox_kpsewhich(matchstr(v:val, ''\C\\\%(input\|include\)\s*{\zs[^}]\+\ze}'')))')

	let bibdata_list +=
				\ map(filter(copy(lines), 'v:val =~ ''\C\\\%(input\|include\)\s\+\S\+'''),
				\ 's:FindBibData(LatexBox_kpsewhich(matchstr(v:val, ''\C\\\%(input\|include\)\s\+\zs\S\+\ze'')))')

	let bibdata = join(bibdata_list, ',')

	return bibdata
endfunction

let s:bstfile = expand('<sfile>:p:h') . '/vimcomplete'

function! LatexBox_BibSearch(regexp)

	" find bib data
    let bibdata = s:FindBibData()
    if bibdata == ''
        echomsg 'error: no \bibliography{...} command found'
        return
    endif

    " write temporary aux file
	let tmpbase = LatexBox_GetTexRoot() . '/_LatexBox_BibComplete'
    let auxfile = tmpbase . '.aux'
    let bblfile = tmpbase . '.bbl'
    let blgfile = tmpbase . '.blg'

    call writefile(['\citation{*}', '\bibstyle{' . s:bstfile . '}', '\bibdata{' . bibdata . '}'], auxfile)

    silent execute '! cd ' shellescape(LatexBox_GetTexRoot()) .
				\ ' ; bibtex -terse ' . fnamemodify(auxfile, ':t') . ' >/dev/null'

    let res = []
    let curentry = ''

	let lines = split(substitute(join(readfile(bblfile), "\n"), '\n\n\@!\(\s\=\)\s*\|{\|}', '\1', 'g'), "\n")

    for line in filter(lines, 'v:val =~ a:regexp')
		let matches = matchlist(line, '^\(.*\)||\(.*\)||\(.*\)||\(.*\)||\(.*\)')
		if !empty(matches) && !empty(matches[1])
			call add(res, {'key': matches[1], 'type': matches[2],
						\ 'author': matches[3], 'year': matches[4], 'title': matches[5]})
		endif
    endfor

	call delete(auxfile)
	call delete(bblfile)
	call delete(blgfile)

	return res
endfunction
" }}}

" BibTeX completion {{{
function! LatexBox_BibComplete(regexp)

	" treat spaces as '.*' if needed
	if g:LatexBox_bibtex_wild_spaces
		"let regexp = substitute(a:regexp, '\s\+', '.*', 'g')
		let regexp = '.*' . substitute(a:regexp, '\s\+', '\\\&.*', 'g')
	else
		let regexp = a:regexp
	endif

    let res = []
    for m in LatexBox_BibSearch(regexp)

        let w = {'word': m['key'],
					\ 'abbr': '[' . m['type'] . '] ' . m['author'] . ' (' . m['year'] . ')',
					\ 'menu': m['title']}

		" close braces if needed
		if g:LatexBox_completion_close_braces && !s:NextCharsMatch('^\s*[,}]')
			let w.word = w.word . '}'
		endif

        call add(res, w)
    endfor
    return res
endfunction
" }}}

" ExtractLabels {{{
" Generate list of \newlabel commands in current buffer.
" 
" Searches the current buffer for commands of the form
"	\newlabel{name}{{number}{page}.* 
" and returns list of [ name, number, page ] tuples.
function! ExtractLabels()
	call cursor(1,1)
	
	let matches = []
	let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )

	while [lblline, lblbegin] != [0,0] 
		let [nln, nameend] = searchpairpos( '{', '', '}', 'W' )
		if nln != lblline
			let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )
			break
		endif
        let curname = strpart( getline( lblline ), lblbegin, nameend - lblbegin - 1 )

        if 0 == search( '{\w*{', 'ce', lblline )
            let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )
            break
        endif

        let numberbegin = getpos('.')[2]
        let [nln, numberend]  = searchpairpos( '{', '', '}', 'W' )
		if nln != lblline
			let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )
			break
		endif
        let curnumber = strpart( getline( lblline ), numberbegin, numberend - numberbegin - 1 )

        if 0 == search( '\w*{', 'ce', lblline )
            let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )
            break
        endif

        let pagebegin = getpos('.')[2]
        let [nln, pageend]  = searchpairpos( '{', '', '}', 'W' )
        if nln != lblline
			let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )
			break
		endif
        let curpage = strpart( getline( lblline ), pagebegin, pageend - pagebegin - 1 )

        let matches += [ [ curname, curnumber, curpage ] ]

        let [lblline, lblbegin] = searchpos( '\\newlabel{', 'ecW' )
	endwhile
	
	return matches 
endfunction
"}}}

" ExtractInputs {{{
" Generate list of \@input commands in current buffer.
"
" Searches the current buffer for \@input{file} entries and
" returns list of all files. 
function! ExtractInputs()
	call cursor(1,1)

	let matches = []
	let [inline, inbegin] = searchpos( '\\@input{', 'ecW' )

	while [inline, inbegin] != [0,0]
		let [nln, inend] = searchpairpos( '{', '', '}', 'W' )
		if nln != inline
			let [inline, inbegin] = searchpos( '\\@input{', 'ecW' )
			break
		endif
		let matches += [ strpart( getline( inline ), inbegin, inend - inbegin - 1 ) ]

		let [inline, inbegin] = searchpos( '\\@input{', 'ecW' )
	endwhile

	return matches
endfunction
"}}}


" s:LabelCache {{{
" Cache of all labels.
"
" LabelCache is a dictionary mapping filenames to tuples
" [ time, labels, inputs ]
" where 
" * time is modification time of the cache entry
" * labels is a list like returned by ExtractLabels
" * inputs is a list like returned by ExtractInputs
let s:LabelCache = {}
"}}}


" GetLabelCache {{{
" Extract labels from LabelCache and update it.
"
" Compares modification time of each entry in the label 
" cache and updates it, if necessary. During traversal of
" the LabelCache, all current labels are collected and 
" returned.
function! s:GetLabelCache(file)
	let fid = fnamemodify(a:file, ':p')

	let labels = []
	if !has_key(s:LabelCache , fid) || s:LabelCache[fid][0] != getftime(fid)
		" Open file in temporary split window for label extraction.
		exe '1sp +let\ labels=ExtractLabels()|quit! ' . fid
		exe '1sp +let\ inputs=ExtractInputs()|quit! ' . fid
		let s:LabelCache[fid] = [ getftime(fid), labels, inputs ]
	else
		let labels = s:LabelCache[fid][1]
	endif

	for input in s:LabelCache[fid][2]
		let labels += s:GetLabelCache(input)
	endfor

	return labels
endfunction
"}}}



" Complete Labels {{{
" the optional argument is the file name to be searched
function! s:CompleteLabels(regex, ...)

	if a:0 == 0
		let file = LatexBox_GetAuxFile()
	else
		let file = a:1
	endif

	if empty(glob(file, 1))
		return []
	endif

	let labels = s:GetLabelCache(file)

	let matches = filter( copy(labels), 'match(v:val[0], "' . a:regex . '") != -1' )
	if empty(matches)
		" also try to match label and number
		let regex_split = split(a:regex)
		if len(regex_split) > 1
			let base = regex_split[0]
			let number = escape(join(regex_split[1:], ' '), '.')
			let matches = filter( copy(labels), 'match(v:val[0], "' . base . '") != -1 && match(v:val[1], "' . number . '") != -1' )
		endif
	endif
	if empty(matches)
		" also try to match number
		let matches = filter( copy(labels), 'match(v:val[1], "' . a:regex . '") != -1' )
	endif

	let suggestions = []
	for m in matches
		let entry = {'word': m[0], 'menu': '(' . m[1] . ') [p.' . m[2] . ']'}
		if g:LatexBox_completion_close_braces && !s:NextCharsMatch('^\s*[,}]')
			" add trailing '}'
			let entry = copy(entry)
			let entry.abbr = entry.word
			let entry.word = entry.word . '}'
		endif
		call add(suggestions, entry)
	endfor

	return suggestions
endfunction
" }}}




" Close Current Environment {{{
function! s:CloseCurEnv()
	" first, try with \left/\right pairs
	let [lnum, cnum] = searchpairpos('\C\\left\>', '', '\C\\right\>', 'bnW', 'LatexBox_InComment()')
	if lnum
		let line = strpart(getline(lnum), cnum - 1)
		let bracket = matchstr(line, '^\\left\zs\((\|\[\|\\{\||\|\.\)\ze')
		for [open, close] in [['(', ')'], ['\[', '\]'], ['\\{', '\\}'], ['|', '|'], ['\.', '|']]
			let bracket = substitute(bracket, open, close, 'g')
		endfor
		return '\right' . bracket
	endif
	
	" second, try with environments
	let env = LatexBox_GetCurrentEnvironment()
	if env == '\['
		return '\]'
	elseif env == '\('
		return '\)'
	elseif env != ''
		return '\end{' . env . '}'
	endif
	return ''
endfunction

" }}}

" Wrap Selection {{{
function! s:WrapSelection(wrapper)
	keepjumps normal! `>a}
	execute 'keepjumps normal! `<i\' . a:wrapper . '{'
endfunction
" }}}

" Wrap Selection in Environment with Prompt {{{
function! s:PromptEnvWrapSelection(...)
	let env = input('environment: ', '', 'customlist,' . s:SIDWrap('GetEnvironmentList'))
	if empty(env)
		return
	endif
	" LaTeXBox's custom indentation can interfere with environment
	" insertion when environments are indented (common for nested
	" environments).  Temporarily disable it for this operation:
	let ieOld = &indentexpr
	setlocal indentexpr=""
	if visualmode() ==# 'V'
		execute 'keepjumps normal! `>o\end{' . env . '}'
		execute 'keepjumps normal! `<O\begin{' . env . '}'
		" indent and format, if requested.
		if a:0 && a:1
			normal! gv>
			normal! gvgq
		endif
	else
		execute 'keepjumps normal! `>a\end{' . env . '}'
		execute 'keepjumps normal! `<i\begin{' . env . '}'
	endif
	exe "setlocal indentexpr=" . ieOld
endfunction
" }}}

" Change Environment {{{
function! s:ChangeEnvPrompt()

	let [env, lnum, cnum, lnum2, cnum2] = LatexBox_GetCurrentEnvironment(1)

	let new_env = input('change ' . env . ' for: ', '', 'customlist,' . s:SIDWrap('GetEnvironmentList'))
	if empty(new_env)
		return
	endif

	if new_env == '\[' || new_env == '['
		let begin = '\['
		let end = '\]'
	elseif new_env == '\(' || new_env == '('
		let begin = '\('
		let end = '\)'
	else
		let l:begin = '\begin{' . new_env . '}'
		let l:end = '\end{' . new_env . '}'
	endif
	
	if env == '\[' || env == '\('
		let line = getline(lnum2)
		let line = strpart(line, 0, cnum2 - 1) . l:end . strpart(line, cnum2 + 1)
		call setline(lnum2, line)

		let line = getline(lnum)
		let line = strpart(line, 0, cnum - 1) . l:begin . strpart(line, cnum + 1)
		call setline(lnum, line)
	else
		let line = getline(lnum2)
		let line = strpart(line, 0, cnum2 - 1) . l:end . strpart(line, cnum2 + len(env) + 5)
		call setline(lnum2, line)

		let line = getline(lnum)
		let line = strpart(line, 0, cnum - 1) . l:begin . strpart(line, cnum + len(env) + 7)
		call setline(lnum, line)
	endif

endfunction

function! s:GetEnvironmentList(lead, cmdline, pos)
	let suggestions = []
	for entry in g:LatexBox_completion_environments
		let env = entry.word
		if env =~ '^' . a:lead
			call add(suggestions, env)
		endif
	endfor
	return suggestions
endfunction
" }}}

" Next Charaters Match {{{
function! s:NextCharsMatch(regex)
	let rest_of_line = strpart(getline('.'), col('.') - 1)
	return rest_of_line =~ a:regex
endfunction
" }}}

" Mappings {{{
imap <silent> <Plug>LatexCloseCurEnv		<C-R>=<SID>CloseCurEnv()<CR>
vmap <silent> <Plug>LatexWrapSelection		:<c-u>call <SID>WrapSelection('')<CR>i
vmap <silent> <Plug>LatexEnvWrapSelection	:<c-u>call <SID>PromptEnvWrapSelection()<CR>
vmap <silent> <Plug>LatexEnvWrapFmtSelection	:<c-u>call <SID>PromptEnvWrapSelection(1)<CR>
nmap <silent> <Plug>LatexChangeEnv			:call <SID>ChangeEnvPrompt()<CR>
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
