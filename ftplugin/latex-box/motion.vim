" LaTeX Box motion functions

" HasSyntax {{{
" s:HasSyntax(syntaxName, [line], [col])
function! s:HasSyntax(syntaxName, ...)
	let line = a:0 >= 1 ? a:1 : line('.')
	let col  = a:0 >= 2 ? a:2 : col('.')
	return index(map(synstack(line, col),
				\ 'synIDattr(v:val, "name") == "' . a:syntaxName . '"'),
				\ 1) >= 0
endfunction
" }}}

" Search and Skip Comments {{{
" s:SearchAndSkipComments(pattern, [flags], [stopline])
function! s:SearchAndSkipComments(pat, ...)
	let flags		= a:0 >= 1 ? a:1 : ''
	let stopline	= a:0 >= 2 ? a:2 : 0
	let saved_pos = getpos('.')

	" search once
	let ret = search(a:pat, flags, stopline)

	if ret
		" do not match at current position if inside comment
		let flags = substitute(flags, 'c', '', 'g')

		" keep searching while in comment
		while LatexBox_InComment()
			let ret = search(a:pat, flags, stopline)
			if !ret
				break
			endif
		endwhile
	endif

	if !ret
		" if no match found, restore position
		call setpos('.', saved_pos)
	endif

	return ret
endfunction
" }}}

" Finding Matching Pair {{{
function! s:FindMatchingPair(mode)

	if a:mode =~ 'h\|i'
		2match none
	elseif a:mode == 'v'
		normal! gv
	endif

	if LatexBox_InComment() | return | endif

	" open/close pairs (dollars signs are treated apart)
	let open_pats  = ['\\{','{','\\(','(','\\\[','\[','\\begin\s*{.\{-}}', '\\left\s*\%([^\\]\|\\.\|\\\a*\)']
	let close_pats = ['\\}','}','\\)',')','\\\]','\]','\\end\s*{.\{-}}',  '\\right\s*\%([^\\]\|\\.\|\\\a*\)']
	let dollar_pat = '\$'
	let notbslash = '\%(\\\@<!\%(\\\\\)*\)\@<='
	let notcomment = '\%(\%(\\\@<!\%(\\\\\)*\)\@<=%.*\)\@<!'
	let anymatch =  '\(' . join(open_pats + close_pats, '\|') . '\|' . dollar_pat . '\)'

	let lnum = line('.')
	let cnum = searchpos('\A', 'cbnW', lnum)[1]
	" if the previous char is a backslash
	if strpart(getline(lnum), 0,  cnum-1) !~ notbslash . '$' | let cnum = cnum-1 | endif
	let delim = matchstr(getline(lnum), '\C^'. anymatch , cnum - 1)

	if empty(delim) || strlen(delim)+cnum-1< col('.')
		if a:mode =~ 'n\|v\|o'
			" if not found, search forward
			let cnum = match(getline(lnum), '\C'. anymatch , col('.') - 1) + 1
			if cnum == 0 | return | endif
			call cursor(lnum, cnum)
			let delim = matchstr(getline(lnum), '\C^'. anymatch , cnum - 1)
		elseif a:mode =~ 'i'
			" if not found, move one char bacward and search
			let cnum = searchpos('\A', 'bnW', lnum)[1]
			" if the previous char is a backslash
			if strpart(getline(lnum), 0,  cnum-1) !~ notbslash . '$' | let cnum = cnum-1 | endif
			let delim = matchstr(getline(lnum), '\C^'. anymatch , cnum - 1)
			if empty(delim) || strlen(delim)+cnum< col('.') | return | endif
		elseif a:mode =~ 'h'
			return
		endif
	endif

	if delim =~ '^\$'

		" match $-pairs
		" check if next character is in inline math
		let [lnum0, cnum0] = searchpos('.', 'nW')
		if lnum0 && s:HasSyntax('texMathZoneX', lnum0, cnum0)
			let [lnum2, cnum2] = searchpos(notcomment . notbslash. dollar_pat, 'nW', line('w$')*(a:mode =~ 'h\|i') , 200)
		else
			let [lnum2, cnum2] = searchpos('\%(\%'. lnum . 'l\%' . cnum . 'c\)\@!'. notcomment . notbslash . dollar_pat, 'bnW', line('w0')*(a:mode =~ 'h\|i') , 200)
		endif

		if a:mode =~ 'h\|i'
			execute '2match MatchParen /\%(\%' . lnum . 'l\%' . cnum . 'c\$' . '\|\%' . lnum2 . 'l\%' . cnum2 . 'c\$\)/'
		elseif a:mode =~ 'n\|v\|o'
			call cursor(lnum2,cnum2)
		endif

	else
		" match other pairs
		for i in range(len(open_pats))
			let open_pat = notbslash . open_pats[i]
			let close_pat = notbslash . close_pats[i]

			if delim =~# '^' . open_pat
				" if on opening pattern, search for closing pattern
				let [lnum2, cnum2] = searchpairpos('\C' . open_pat, '', '\C' . close_pat, 'nW', 'LatexBox_InComment()', line('w$')*(a:mode =~ 'h\|i') , 200)
				if a:mode =~ 'h\|i'
					execute '2match MatchParen /\%(\%' . lnum . 'l\%' . cnum . 'c' . open_pats[i] . '\|\%' . lnum2 . 'l\%' . cnum2 . 'c' . close_pats[i] . '\)/'
				elseif a:mode =~ 'n\|v\|o'
					call cursor(lnum2,cnum2)
					if strlen(close_pat)>1 && a:mode =~ 'o'
						call cursor(lnum2, matchend(getline('.'), '\C' . close_pat, col('.')-1))
					endif
				endif
				break
			elseif delim =~# '^' . close_pat
				" if on closing pattern, search for opening pattern
				let [lnum2, cnum2] =  searchpairpos('\C' . open_pat, '', '\C\%(\%'. lnum . 'l\%' . cnum . 'c\)\@!' . close_pat, 'bnW', 'LatexBox_InComment()', line('w0')*(a:mode =~ 'h\|i') , 200)
				if a:mode =~ 'h\|i'
					execute '2match MatchParen /\%(\%' . lnum2 . 'l\%' . cnum2 . 'c' . open_pats[i] . '\|\%' . lnum . 'l\%' . cnum . 'c' . close_pats[i] . '\)/'
				elseif a:mode =~ 'n\|v\|o'
					call cursor(lnum2,cnum2)
				endif
				break
			endif
		endfor

	endif
endfunction

" disable matchparen autocommands
augroup LatexBox_HighlightPairs
	autocmd BufEnter * if !exists("g:loaded_matchparen") || !g:loaded_matchparen | runtime plugin/matchparen.vim | endif
	autocmd BufEnter *.tex 3match none | unlet! g:loaded_matchparen | au! matchparen
	autocmd! CursorMoved *.tex call s:FindMatchingPair('h')
	autocmd! CursorMovedI *.tex call s:FindMatchingPair('i')
augroup END

nnoremap <silent> <Plug>LatexBox_JumpToMatch		:call <SID>FindMatchingPair('n')<CR>
vnoremap <silent> <Plug>LatexBox_JumpToMatch		:call <SID>FindMatchingPair('v')<CR>
onoremap <silent> <Plug>LatexBox_JumpToMatch		v:call <SID>FindMatchingPair('o')<CR>
" }}}

" select inline math {{{
" s:SelectInlineMath(seltype)
" where seltype is either 'inner' or 'outer'
function! s:SelectInlineMath(seltype)

	let dollar_pat = '\\\@<!\$'

	if s:HasSyntax('texMathZoneX')
		call s:SearchAndSkipComments(dollar_pat, 'cbW')
	elseif getline('.')[col('.') - 1] == '$'
		call s:SearchAndSkipComments(dollar_pat, 'bW')
	else
		return
	endif

	if a:seltype == 'inner'
		normal! l
	endif

	if visualmode() ==# 'V'
		normal! V
	else
		normal! v
	endif

	call s:SearchAndSkipComments(dollar_pat, 'W')

	if a:seltype == 'inner'
		normal! h
	endif
endfunction

vnoremap <silent> <Plug>LatexBox_SelectInlineMathInner
			\ :<C-U>call <SID>SelectInlineMath('inner')<CR>
vnoremap <silent> <Plug>LatexBox_SelectInlineMathOuter
			\ :<C-U>call <SID>SelectInlineMath('outer')<CR>
" }}}

" select current environment {{{
function! s:SelectCurrentEnv(seltype)
	let [env, lnum, cnum, lnum2, cnum2] = LatexBox_GetCurrentEnvironment(1)
	call cursor(lnum, cnum)
	if a:seltype == 'inner'
		if env =~ '^\'
			call search('\\.\_\s*\S', 'eW')
		else
			call search('}\(\_\s*\[\_[^]]*\]\)\?\_\s*\S', 'eW')
		endif
	endif
	if visualmode() ==# 'V'
		normal! V
	else
		normal! v
	endif
	call cursor(lnum2, cnum2)
	if a:seltype == 'inner'
		call search('\S\_\s*', 'bW')
	else
		if env =~ '^\'
			normal! l
		else
			call search('}', 'eW')
		endif
	endif
endfunction
vnoremap <silent> <Plug>LatexBox_SelectCurrentEnvInner :<C-U>call <SID>SelectCurrentEnv('inner')<CR>
vnoremap <silent> <Plug>LatexBox_SelectCurrentEnvOuter :<C-U>call <SID>SelectCurrentEnv('outer')<CR>
" }}}

" Jump to the next braces {{{
"
function! LatexBox_JumpToNextBraces(backward)
	let flags = ''
	if a:backward
		normal h
		let flags .= 'b'
	else
		let flags .= 'c'
	endif
	if search('[][}{]', flags) > 0
		normal l
	endif
	let prev = strpart(getline('.'), col('.') - 2, 1)
	let next = strpart(getline('.'), col('.') - 1, 1)
	if next =~ '[]}]' && prev !~ '[][{}]'
		return "\<Right>"
	else
		return ''
	endif
endfunction
" }}}

" Table of Contents {{{

" Special UTF-8 conversion
function! s:ConvertBack(line)

	let line = a:line

	if !exists('g:LatexBox_plaintext_toc')
		let line = substitute(line, "\\\\IeC\s*{\\\\'a}", 'á', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`a}", 'à', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^a}", 'à', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨a}", 'ä', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"a}", 'ä', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'e}", 'é', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`e}", 'è', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^e}", 'ê', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨e}", 'ë', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"e}", 'ë', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'i}", 'í', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`i}", 'î', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^i}", 'ì', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨i}", 'ï', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"i}", 'ï', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'o}", 'ó', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`o}", 'ò', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^o}", 'ô', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨o}", 'ö', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"o}", 'ö', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'u}", 'ú', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`u}", 'ù', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^u}", 'û', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨u}", 'ü', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"u}", 'ü', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'A}", 'Á', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`A}", 'À', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^A}", 'À', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨A}", 'Ä', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"A}", 'Ä', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'E}", 'É', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`E}", 'È', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^E}", 'Ê', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨E}", 'Ë', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"E}", 'Ë', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'I}", 'Í', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`I}", 'Î', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^I}", 'Ì', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨I}", 'Ï', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"I}", 'Ï', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'O}", 'Ó', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`O}", 'Ò', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^O}", 'Ô', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨O}", 'Ö', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"O}", 'Ö', 'g')

		let line = substitute(line, "\\\\IeC\s*{\\\\'U}", 'Ú', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\`U}", 'Ù', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\^U}", 'Û', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\¨U}", 'Ü', 'g')
		let line = substitute(line, "\\\\IeC\s*{\\\\\"U}", 'Ü', 'g')

	else
		" substitute stuff like '\IeC{\"u}' (utf-8 umlauts in section heading)
		" to plain 'u'
		let line = substitute(line, "\\\\IeC\s*{\\\\.\\(.\\)}", '\1', 'g')
	endif
	return line

endfunction

function! s:ReadTOC(auxfile, ...)

	let texfile = fnamemodify(substitute(a:auxfile, '\.aux$', '.tex', ''), ':p')
	let prefix = fnamemodify(a:auxfile, ':p:h')

	if a:0 != 2
		let toc = []
		let fileindices = { texfile : [] }
	else
		let toc = a:1
		let fileindices = a:2
		let fileindices[ texfile ] = []
	endif


	for line in readfile(a:auxfile)

		let included = matchstr(line, '^\\@input{\zs[^}]*\ze}')

		if included != ''
			" append the input TOX to `toc` and `fileindices`
			call s:ReadTOC(prefix . '/' . included, toc, fileindices)
			continue
		endif

		" Parse statements like:
		" \@writefile{toc}{\contentsline {section}{\numberline {secnum}Section Title}{pagenumber}}
		" \@writefile{toc}{\contentsline {section}{\tocsection {}{1}{Section Title}}{pagenumber}}
		" \@writefile{toc}{\contentsline {section}{\numberline {secnum}Section Title}{pagenumber}{otherstuff}}

		let line = matchstr(line, '\\@writefile{toc}{\\contentsline\s*\zs.*\ze}\s*$')
		if empty(line)
			continue
		endif

		let tree = LatexBox_TexToTree(line)

		if len(tree) < 3
			" unknown entry type: just skip it
			continue
		endif

		" parse level
		let level = tree[0][0]
		" parse page
		if !empty(tree[2])
			let page = tree[2][0]
		else
			let page = ''
		endif
		" parse section number
		if len(tree[1]) > 3 && empty(tree[1][1])
			call remove(tree[1], 1)
		endif
		let secnum = ""
		if len(tree[1]) > 1
			if !empty(tree[1][1])
				let secnum = tree[1][1][0]
			endif
			let tree = tree[1][2:]
		else
			let secnum = ''
			let tree = tree[1]
		endif
		" parse section title
		let text = LatexBox_TreeToTex(tree)
		let text = s:ConvertBack(text)
		let text = substitute(text, '^{\+\|}\+$', '', 'g')

		" add TOC entry
		call add(fileindices[texfile], len(toc))
		call add(toc, {'file': texfile, 'level': level, 'number': secnum, 'text': text, 'page': page})
	endfor

	return [toc, fileindices]

endfunction

function! LatexBox_TOC()

	" check if window already exists
	let winnr = bufwinnr(bufnr('LaTeX TOC'))
	if winnr >= 0
		silent execute winnr . 'wincmd w'
		return
	endif

	" read TOC
	let [toc, fileindices] = s:ReadTOC(LatexBox_GetAuxFile())
	let calling_buf = bufnr('%')

	" find closest section in current buffer
	let closest_index = s:FindClosestSection(toc,fileindices)

	" create TOC window and set local settings
	execute g:LatexBox_split_side g:LatexBox_split_width . 'vnew LaTeX\ TOC'
	setlocal buftype=nofile
				\ bufhidden=wipe
				\ nobuflisted
				\ noswapfile
				\ nowrap
				\ cursorline
				\ nonumber
				\ nolist
				\ tabstop=8

	" add TOC entries
	for entry in toc
		call append('$', entry['number'] . "\t" . entry['text'])
	endfor
	call append('$', ["", "<Esc>/q: close",
				\ "<Space>: jump", "<Enter>: jump and close"])
	0delete _

	" syntax
	syntax match helpText /^<.*/
	syntax match secNum /^\S\+/ contained
	syntax match secLine /^\S\+\t\S\+/ contains=secNum
	syntax match mainSecLine /^[^\.]\+\t.*/ contains=secNum
	syntax match ssubSecLine /^[^\.]\+\.[^\.]\+\.[^\.]\+\t.*/ contains=secNum
	highlight link helpText		PreProc
	highlight link secNum		Number
	highlight link mainSecLine	Title
	highlight link ssubSecLine	Comment

	" mappings
	map <buffer> <silent> q			:bwipeout<CR>
	map <buffer> <silent> <Esc>		:bwipeout<CR>
	map <buffer> <silent> <Space> 	:call <SID>TOCActivate(0)<CR>
	map <buffer> <silent> <CR> 		:call <SID>TOCActivate(1)<CR>
	nnoremap <silent> <buffer> <leftrelease> :call <SID>TOCActivate(0)<cr>
	nnoremap <silent> <buffer> <2-leftmouse> :call <SID>TOCActivate(1)<cr>
	nnoremap <buffer> <silent> G	G4k
	map <buffer> <silent> OA k
	map <buffer> <silent> OB j
	map <buffer> <silent> OC l
	map <buffer> <silent> OD h

	" lock buffer
	setlocal nomodifiable

	let b:toc = toc
	let b:calling_win = bufwinnr(calling_buf)

	" jump to closest section
	execute 'normal! ' . (closest_index + 1) . 'G'

endfunction

" Binary search for the closest section
" return the index of the TOC entry
function! s:FindClosestSection(toc, fileindices)
	let file = expand('%:p')
	if !has_key(a:fileindices, file)
		echoe 'Current file is not included in main tex file ' . LatexBox_GetMainTexFile() . '.'
	endif

	let imax = len(a:fileindices[file])
	let imin = 0
	while imin < imax - 1
		let i = (imax + imin) / 2
		let tocindex = a:fileindices[file][i]
		let entry = a:toc[tocindex]
		let titlestr = entry['text']
		let titlestr = escape(titlestr, '\')
		let titlestr = substitute(titlestr, ' ', '\\_\\s\\+', 'g')
		let [lnum, cnum] = searchpos('\\' . entry['level'] . '\_\s*{' . titlestr . '}', 'nW')
		if lnum
			let imax = i
		else
			let imin = i
		endif
	endwhile

	return a:fileindices[file][imin]
endfunction

function! s:EscapeTitle(titlestr)
	" Credit goes to Marcin Szamotulski for the following fix.  It allows to
	" match through commands added by TeX.
	let titlestr = substitute(a:titlestr, '\\\w*\>\s*\%({[^}]*}\)\?', '.*', 'g')

	let titlestr = escape(titlestr, '\')
	let titlestr = substitute(titlestr, ' ', '\\_\\s\\+', 'g')

	return titlestr
endfunction

function! s:TOCActivate(close)
	let n = getpos('.')[1] - 1

	if n >= len(b:toc)
		return
	endif

	let entry = b:toc[n]

	let titlestr = s:EscapeTitle(entry['text'])

	" Search for duplicates
	"
	let i=0
	let entry_hash = entry['level'].titlestr
	let duplicates = 0
	while i<n
		let i_entry = b:toc[n]
		let i_hash = b:toc[i]['level'].s:EscapeTitle(b:toc[i]['text'])
		if i_hash == entry_hash
			let duplicates += 1
		endif
		let i += 1
	endwhile
	let toc_bnr = bufnr('%')
	let toc_wnr = winnr()

	execute b:calling_win . 'wincmd w'

	let bnr = bufnr(entry['file'])
	if bnr == -1
		execute 'badd ' . entry['file']
		let bnr = bufnr(entry['file'])
	endif

	execute 'buffer! ' . bnr


	" skip duplicates
	while duplicates > 0
		if search('\\' . entry['level'] . '\_\s*{' . titlestr . '}', 'ws')
			let duplicates -= 1
		endif
	endwhile

	if search('\\' . entry['level'] . '\_\s*{' . titlestr . '}', 'ws')
		normal zt
	endif

	if a:close
		execute 'bwipeout ' . toc_bnr
	else
		execute toc_wnr . 'wincmd w'
	endif
endfunction
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
