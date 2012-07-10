" LaTeX indent file (part of LaTeX Box)
" Maintainer: David Munger (mungerd@gmail.com)

if exists("b:did_indent")
	finish
endif

let b:did_indent = 1

setlocal indentexpr=LatexBox_TexIndent()
setlocal indentkeys=0=\\end,0=\\end{enumerate},0=\\end{itemize},0=\\item,0),0],0},o,O,0\\

let s:itemize_envs = ['itemize', 'enumerate', 'description']

" indent on \left( and on \(, but not on (
" indent on \left[ and on \[, but not on [ and \[...]
" indent on \left\{ and on \{, and on {
let s:open_pat = '\\begin\>\|\%(\\left\s*\)\=\\\=[{]\|\%(\\left\s*\|\\\)\([[]\(\p\+]\)\@!\|[)]\)'
let s:close_pat = '\\end\>\|\%(\\right\s*\)\=\\\=[}]\|\%(\\right\s*\|\\\)[])]'


" Compute Level {{{
function! s:ComputeLevel(lnum_prev, open_pat, close_pat)

	let n = 0

	let line_prev = getline(a:lnum_prev)

	" strip comments
	let line_prev = substitute(line_prev, '\\\@<!%.*', '', 'g')

	" find unmatched opening patterns on previous line
	let n += len(substitute(substitute(line_prev, a:open_pat, "\n", 'g'), "[^\n]", '', 'g'))
	let n -= len(substitute(substitute(line_prev, a:close_pat, "\n", 'g'), "[^\n]", '', 'g'))

	" reduce indentation if current line starts with a closing pattern
	if getline(v:lnum) =~ '^\s*\%(' . a:close_pat . '\)'
		let n -= 1
	endif

	" compensate indentation if previous line starts with a closing pattern
	if line_prev =~ '^\s*\%(' . a:close_pat . '\)'
		let n += 1
	endif
	
	return n
endfunction
" }}}

" TexIndent {{{
function! LatexBox_TexIndent()

	let lnum_prev = prevnonblank(v:lnum - 1)

	if lnum_prev == 0
		return 0
	endif

	let n = 0

	let n += s:ComputeLevel(lnum_prev, s:open_pat, s:close_pat)

	let n += s:ComputeLevel(lnum_prev, '\\begin{\%(' . join(s:itemize_envs, '\|') . '\)}',
				\ '\\end{\%(' . join(s:itemize_envs, '\|') . '\)}')

	" less shift for lines starting with \item
	let item_here = getline(v:lnum) =~ '^\s*\\item'
	let item_above = getline(lnum_prev) =~ '^\s*\\item'
	if !item_here && item_above
		let n += 1
	elseif item_here && !item_above
		let n -= 1
	endif

	return indent(lnum_prev) + n * &sw
endfunction
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
