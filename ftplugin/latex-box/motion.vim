" LaTeX Box motion functions

" HasSyntax {{{
" s:HasSyntax(syntaxName, [line], [col])
function! s:HasSyntax(syntaxName, ...)
	let line	= a:0 >= 1 ? a:1 : line('.')
	let col		= a:0 >= 2 ? a:2 : col('.')
	return index(map(synstack(line, col), 'synIDattr(v:val, "name") == "' . a:syntaxName . '"'), 1) >= 0
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

" begin/end pairs {{{
"
" s:JumpToMatch(mode, [backward])
" - search backwards if backward is given and nonzero
" - search forward otherwise
"
function! s:JumpToMatch(mode, ...)

	if a:0 >= 1
		let backward = a:1
	else
		let backward = 0
	endif

	let sflags = backward ? 'cbW' : 'cW'

	" selection is lost upon function call, reselect
	if a:mode == 'v'
		normal! gv
	endif

	" open/close pairs (dollars signs are treated apart)
	let open_pats  = ['{', '\[', '(', '\\begin\>', '\\left\>', '\\lceil\>', '\\lgroup\>', '\\lfloor', '\\langle']
	let close_pats = ['}', '\]', ')', '\\end\>', '\\right\>', '\\rceil', '\\rgroup\>', '\\rfloor', '\\rangle']
	let dollar_pat = '\\\@<!\$'

	let saved_pos = getpos('.')

	" move to the left until not on alphabetic characters
	call search('\A', 'cbW', line('.'))

	" go to next opening/closing pattern on same line
	if !s:SearchAndSkipComments(
				\	'\m\C\%(' . join(open_pats + close_pats + [dollar_pat], '\|') . '\)',
				\	sflags, line('.'))
		" abort if no match or if match is inside a comment
		call setpos('.', saved_pos)
		return
	endif

	let rest_of_line = strpart(getline('.'), col('.') - 1)

	" match for '$' pairs
	if rest_of_line =~ '^\$'

		" check if next character is in inline math
		let [lnum, cnum] = searchpos('.', 'nW')
		if lnum && s:HasSyntax('texMathZoneX', lnum, cnum)
			call s:SearchAndSkipComments(dollar_pat, 'W')
		else
			call s:SearchAndSkipComments(dollar_pat, 'bW')
		endif

	else

		" match other pairs
		for i in range(len(open_pats))
			let open_pat = open_pats[i]
			let close_pat = close_pats[i]

			if rest_of_line =~ '^\C\%(' . open_pat . '\)'
				" if on opening pattern, go to closing pattern
				call searchpair('\C' . open_pat, '', '\C' . close_pat, 'W', 'LatexBox_InComment()')
				break
			elseif rest_of_line =~ '^\C\%(' . close_pat . '\)'
				" if on closing pattern, go to opening pattern
				call searchpair('\C' . open_pat, '', '\C' . close_pat, 'bW', 'LatexBox_InComment()')
				break
			endif

		endfor
	endif

endfunction

nnoremap <silent> <Plug>LatexBox_JumpToMatch		:call <SID>JumpToMatch('n')<CR>
vnoremap <silent> <Plug>LatexBox_JumpToMatch		:<C-U>call <SID>JumpToMatch('v')<CR>
nnoremap <silent> <Plug>LatexBox_BackJumpToMatch	:call <SID>JumpToMatch('n', 1)<CR>
vnoremap <silent> <Plug>LatexBox_BackJumpToMatch	:<C-U>call <SID>JumpToMatch('v', 1)<CR>
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

vnoremap <silent> <Plug>LatexBox_SelectInlineMathInner :<C-U>call <SID>SelectInlineMath('inner')<CR>
vnoremap <silent> <Plug>LatexBox_SelectInlineMathOuter :<C-U>call <SID>SelectInlineMath('outer')<CR>
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

"Special UTF-8 conversion
function! s:ConvertBack(line)

        let line = a:line

        let line = substitute(line, "\\\\IeC\s*{\\\\'a}", 'á', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`a}", 'à', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^a}", 'à', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'e}", 'é', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`e}", 'è', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^e}", 'ê', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'i}", 'í', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`i}", 'î', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^i}", 'ì', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'o}", 'ó', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`o}", 'ò', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^o}", 'ô', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'u}", 'ú', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`u}", 'ù', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^u}", 'û', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'A}", 'Á', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`A}", 'À', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^A}", 'À', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'E}", 'É', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`E}", 'È', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^E}", 'Ê', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'I}", 'Í', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`I}", 'Î', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^I}", 'Ì', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'O}", 'Ó', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`O}", 'Ò', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^O}", 'Ô', 'g')

        let line = substitute(line, "\\\\IeC\s*{\\\\'U}", 'Ú', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\`U}", 'Ù', 'g')
        let line = substitute(line, "\\\\IeC\s*{\\\\^U}", 'Û', 'g')

        return line

endfunction

function! s:ReadTOC(auxfile)

	let toc = []

	let prefix = fnamemodify(a:auxfile, ':p:h')

	for line in readfile(a:auxfile)

		let included = matchstr(line, '^\\@input{\zs[^}]*\ze}')
		
		if included != ''
			call extend(toc, s:ReadTOC(prefix . '/' . included))
			continue
		endif

		" Parse lines like:
		" \@writefile{toc}{\contentsline {section}{\numberline {secnum}Section Title}{pagenumber}}
		" \@writefile{toc}{\contentsline {section}{\tocsection {}{1}{Section Title}}{pagenumber}}
		" \@writefile{toc}{\contentsline {section}{\numberline {secnum}Section Title}{pagenumber}{otherstuff}}

		let line = matchstr(line, '^\\@writefile{toc}{\\contentsline\s*\zs.*\ze}\s*$')
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
		" substitute stuff like '\IeC{\"u}' (utf-8 umlauts in section heading) to plain 'u'
		let text = substitute(text, '\v\\IeC\{\\"(.)\}', '\1', 'g')

		" add TOC entry
		call add(toc, {'file': bufname('%'),
					\ 'level': level, 'number': secnum, 'text': text, 'page': page})
	endfor

	return toc

endfunction

function! LatexBox_TOC()

	" check if window already exists
	let winnr = bufwinnr(bufnr('LaTeX TOC'))
	if winnr >= 0
		silent execute winnr . 'wincmd w'
		return
	endif

	" read TOC
	let toc = s:ReadTOC(LatexBox_GetAuxFile())
	let calling_buf = bufnr('%')

	" find closest section in current buffer
	let closest_index = s:FindClosestSection(toc)

	execute g:LatexBox_split_side g:LatexBox_split_width . 'vnew LaTeX\ TOC'
	setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap cursorline nonumber

	for entry in toc
		call append('$', entry['number'] . "\t" . entry['text'])
	endfor
	call append('$', ["", "<Esc>/q: close", "<Space>: jump", "<Enter>: jump and close"])

	0delete

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

	map <buffer> <silent> q			:bwipeout<CR>
	map <buffer> <silent> <Esc>		:bwipeout<CR>
	map <buffer> <silent> <Space> 	:call <SID>TOCActivate(0)<CR>
	map <buffer> <silent> <CR> 		:call <SID>TOCActivate(1)<CR>
    nnoremap <silent> <buffer> <leftrelease> :call <SID>TOCActivate(0)<cr>
    nnoremap <silent> <buffer> <2-leftmouse> :call <SID>TOCActivate(1)<cr>
	nnoremap <buffer> <silent> G	G4k

	setlocal nomodifiable tabstop=8

	let b:toc = toc
	let b:calling_win = bufwinnr(calling_buf)

	" jump to closest section
	execute 'normal! ' . (closest_index + 1) . 'G'

endfunction

" Binary search for the closest section
" return the index of the TOC entry
function! s:FindClosestSection(toc)
	let imax = len(a:toc)
	let imin = 0
	while imin < imax - 1
		let i = (imax + imin) / 2
		let entry = a:toc[i]
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

	return imin
endfunction

function! s:TOCActivate(close)
	let n = getpos('.')[1] - 1

	if n >= len(b:toc)
		return
	endif

	let entry = b:toc[n]

	let toc_bnr = bufnr('%')
	let toc_wnr = winnr()

	execute b:calling_win . 'wincmd w'

	let bnr = bufnr(entry['file'])
	if bnr >= 0
		execute 'buffer ' . bnr
	else
		execute 'edit ' . entry['file']
	endif

	let titlestr = entry['text']

	" Credit goes to Marcin Szamotulski for the following fix. It allows to match through
	" commands added by TeX.
	let titlestr = substitute(titlestr, '\\\w*\>\s*\%({[^}]*}\)\?', '.*', 'g')

	let titlestr = escape(titlestr, '\')
	let titlestr = substitute(titlestr, ' ', '\\_\\s\\+', 'g')

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

" Highlight Matching Pair {{{
function! s:HighlightMatchingPair()

	2match none

	if LatexBox_InComment()
		return
	endif

	let open_pats = ['\\begin\>', '\\left\>']
	let close_pats = ['\\end\>', '\\right\>']
	let dollar_pat = '\\\@<!\$'

	let saved_pos = getpos('.')

	if getline('.')[col('.') - 1] == '$'

	   if strpart(getline('.'), col('.') - 2, 1) == '\'
		   return
	   endif

		" match $-pairs
		let lnum = line('.')
		let cnum = col('.')
	
		" check if next character is in inline math
		let [lnum2, cnum2] = searchpos('.', 'nW')
		if lnum2 && s:HasSyntax('texMathZoneX', lnum2, cnum2)
			call s:SearchAndSkipComments(dollar_pat, 'W')
		else
			call s:SearchAndSkipComments(dollar_pat, 'bW')
		endif

		execute '2match MatchParen /\%(\%' . lnum . 'l\%' . cnum . 'c\$'
					\	. '\|\%' . line('.') . 'l\%' . col('.') . 'c\$\)/'

	else
		" match other pairs

		" find first non-alpha character to the left on the same line
		let [lnum, cnum] = searchpos('\A', 'cbW', line('.'))

		let delim = matchstr(getline(lnum), '^\m\(' . join(open_pats + close_pats, '\|') . '\)', cnum - 1)

		if empty(delim)
			call setpos('.', saved_pos)
			return
		endif

		for i in range(len(open_pats))
			let open_pat = open_pats[i]
			let close_pat = close_pats[i]

			if delim =~# '^' . open_pat
				" if on opening pattern, go to closing pattern
				call searchpair('\C' . open_pat, '', '\C' . close_pat, 'W', 'LatexBox_InComment()')
				execute '2match MatchParen /\%(\%' . lnum . 'l\%' . cnum . 'c' . open_pats[i]
							\	. '\|\%' . line('.') . 'l\%' . col('.') . 'c' . close_pats[i] . '\)/'
				break
			elseif delim =~# '^' . close_pat
				" if on closing pattern, go to opening pattern
				call searchpair('\C' . open_pat, '', '\C' . close_pat, 'bW', 'LatexBox_InComment()')
				execute '2match MatchParen /\%(\%' . line('.') . 'l\%' . col('.') . 'c' . open_pats[i]
							\	. '\|\%' . lnum . 'l\%' . cnum . 'c' . close_pats[i] . '\)/'
				break
			endif
		endfor
	endif

	call setpos('.', saved_pos)
endfunction
" }}}

augroup LatexBox_HighlightPairs
  " Replace all matchparen autocommands
  autocmd! CursorMoved *.tex call s:HighlightMatchingPair()
  autocmd! CursorMovedi *.tex call s:HighlightMatchingPair()
augroup END

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
