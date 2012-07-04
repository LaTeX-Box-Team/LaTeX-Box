" LaTeX Box common functions

" Settings {{{

" Compilation {{{

" g:vim_program {{{
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
" }}}

if !exists('g:LatexBox_latexmk_options')
	let g:LatexBox_latexmk_options = ''
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
" }}}

" Completion {{{
if !exists('g:LatexBox_completion_close_braces')
	let g:LatexBox_completion_close_braces = 1
endif
if !exists('g:LatexBox_bibtex_wild_spaces')
	let g:LatexBox_bibtex_wild_spaces = 1
endif

if !exists('g:LatexBox_cite_pattern')
	let g:LatexBox_cite_pattern = '\C\\cite\(p\|t\)\=\*\=\(\[[^\]]*\]\)*\_\s*{'
endif
if !exists('g:LatexBox_ref_pattern')
	let g:LatexBox_ref_pattern = '\C\\v\?\(eq\|page\)\?ref\*\?\_\s*{'
endif

if !exists('g:LatexBox_completion_environments')
	let g:LatexBox_completion_environments = [
		\ {'word': 'itemize',		'menu': 'bullet list' },
		\ {'word': 'enumerate',		'menu': 'numbered list' },
		\ {'word': 'description',	'menu': 'description' },
		\ {'word': 'center',		'menu': 'centered text' },
		\ {'word': 'figure',		'menu': 'floating figure' },
		\ {'word': 'table',			'menu': 'floating table' },
		\ {'word': 'equation',		'menu': 'equation (numbered)' },
		\ {'word': 'align',			'menu': 'aligned equations (numbered)' },
		\ {'word': 'align*',		'menu': 'aligned equations' },
		\ {'word': 'document' },
		\ {'word': 'abstract' },
		\ ]
endif

if !exists('g:LatexBox_completion_commands')
	let g:LatexBox_completion_commands = [
		\ {'word': '\begin{' },
		\ {'word': '\end{' },
		\ {'word': '\item' },
		\ {'word': '\label{' },
		\ {'word': '\ref{' },
		\ {'word': '\eqref{eq:' },
		\ {'word': '\cite{' },
		\ {'word': '\chapter{' },
		\ {'word': '\section{' },
		\ {'word': '\subsection{' },
		\ {'word': '\subsubsection{' },
		\ {'word': '\paragraph{' },
		\ {'word': '\nonumber' },
		\ {'word': '\bibliography' },
		\ {'word': '\bibliographystyle' },
		\ ]
endif
" }}}

" Vim Windows {{{

" width of vertical splits
if !exists('g:LatexBox_split_width')
	let g:LatexBox_split_width = 30
endif

" where vertical splits appear
if !exists('g:LatexBox_split_side')
	let g:LatexBox_split_side = "leftabove"
endif

" }}}
" }}}

" Filename utilities {{{
"
function! LatexBox_GetMainTexFile()

	" 1. check for the b:main_tex_file variable
	if exists('b:main_tex_file') && glob(b:main_tex_file, 1) != ''
		return b:main_tex_file
	endif

	" 2. scan current file for "\begin{document}"
	if &filetype == 'tex' && search('\C\\begin\_\s*{document}', 'nw') != 0
		return expand('%:p')
	endif

	" 3. scan the first few lines of the file for root = filename
	for linenum in range(1,5)
		let linecontents = getline(linenum)
		if linecontents =~ 'root\s*='
			" Remove everything but the filename
			let b:main_tex_file = substitute(linecontents, '.*root\s*=\s*', "", "")
			let b:main_tex_file = substitute(b:main_tex_file, '\s*$', "", "")
			let b:main_tex_file = fnamemodify(b:main_tex_file, ":p")
			return b:main_tex_file
		endif
	endfor

	" 4. prompt for file with completion
	let b:main_tex_file = s:PromptForMainFile()
	return b:main_tex_file
endfunction

function! s:PromptForMainFile()
	let saved_dir = getcwd()
	execute 'cd ' . fnameescape(expand('%:p:h'))
	let l:file = ''
	while glob(l:file, 1) == ''
		let l:file = input('main LaTeX file: ', '', 'file')
		if l:file !~ '\.tex$'
			let l:file .= '.tex'
		endif
	endwhile
	execute 'cd ' . fnameescape(saved_dir)
	return l:file
endfunction

" Return the directory of the main tex file
function! LatexBox_GetTexRoot()
	return fnamemodify(LatexBox_GetMainTexFile(), ':h')
endfunction

function! LatexBox_GetTexBasename(with_dir)
	if a:with_dir
		return fnamemodify(LatexBox_GetMainTexFile(), ':r')
	else
		return fnamemodify(LatexBox_GetMainTexFile(), ':t:r')
	endif
endfunction

function! LatexBox_GetAuxFile()
	return LatexBox_GetTexBasename(1) . '.aux'
endfunction

function! LatexBox_GetLogFile()
	return LatexBox_GetTexBasename(1) . '.log'
endfunction

function! LatexBox_GetOutputFile()
	return LatexBox_GetTexBasename(1) . '.' . g:LatexBox_output_type
endfunction
" }}}

" View Output {{{
function! LatexBox_View()
	let outfile = LatexBox_GetOutputFile()
	if !filereadable(outfile)
		echomsg fnamemodify(outfile, ':.') . ' is not readable'
		return
	endif
	let cmd = '!' . g:LatexBox_viewer . ' ' . shellescape(outfile) . ' >&/dev/null &'
	silent execute cmd
	if !has("gui_running")
		redraw!
	endif
endfunction

command! LatexView			call LatexBox_View()
" }}}

" In Comment {{{
" LatexBox_InComment([line], [col])
" return true if inside comment
function! LatexBox_InComment(...)
	let line	= a:0 >= 1 ? a:1 : line('.')
	let col		= a:0 >= 2 ? a:2 : col('.')
	return synIDattr(synID(line("."), col("."), 0), "name") =~# '^texComment'
endfunction
" }}}

" Get Current Environment {{{
" LatexBox_GetCurrentEnvironment([with_pos])
" Returns:
" - environment													if with_pos is not given
" - [envirnoment, lnum_begin, cnum_begin, lnum_end, cnum_end]	if with_pos is nonzero
function! LatexBox_GetCurrentEnvironment(...)

	if a:0 > 0
		let with_pos = a:1
	else
		let with_pos = 0
	endif

	let begin_pat = '\C\\begin\_\s*{[^}]*}\|\\\@<!\\\[\|\\\@<!\\('
	let end_pat = '\C\\end\_\s*{[^}]*}\|\\\@<!\\\]\|\\\@<!\\)'
	let saved_pos = getpos('.')

	" move to the left until on a backslash
	let [bufnum, lnum, cnum, off] = getpos('.')
	let line = getline(lnum)
	while cnum > 1 && line[cnum - 1] != '\'
		let cnum -= 1
	endwhile
	call cursor(lnum, cnum)

	" match begin/end pairs but skip comments
	let flags = 'bnW'
	if strpart(getline('.'), col('.') - 1) =~ '^\%(' . begin_pat . '\)'
		let flags .= 'c'
	endif
	let [lnum1, cnum1] = searchpairpos(begin_pat, '', end_pat, flags, 'LatexBox_InComment()')

	let env = ''

	if lnum1

		let line = strpart(getline(lnum1), cnum1 - 1)

		if empty(env)
			let env = matchstr(line, '^\C\\begin\_\s*{\zs[^}]*\ze}')
		endif
		if empty(env)
			let env = matchstr(line, '^\\\[')
		endif
		if empty(env)
			let env = matchstr(line, '^\\(')
		endif

	endif

	if with_pos == 1

		let flags = 'nW'
		if !(lnum1 == lnum && cnum1 == cnum)
			let flags .= 'c'
		endif

		let [lnum2, cnum2] = searchpairpos(begin_pat, '', end_pat, flags, 'LatexBox_InComment()')
		call setpos('.', saved_pos)
		return [env, lnum1, cnum1, lnum2, cnum2]
	else
		call setpos('.', saved_pos)
		return env
	endif


endfunction
" }}}


" Tex To Tree {{{
" stores nested braces in a tree structure
function! LatexBox_TexToTree(str)
	let tree = []
	let i1 = 0
	let i2 = -1
	let depth = 0
	while i2 < len(a:str)
		let i2 = match(a:str, '[{}]', i2 + 1)
		if i2 < 0
			let i2 = len(a:str)
		endif
		if i2 >= len(a:str) || a:str[i2] == '{'
			if depth == 0 
				let item = substitute(strpart(a:str, i1, i2 - i1), '^\s*\|\s*$', '', 'g')
				if !empty(item)
					call add(tree, item)
				endif
				let i1 = i2 + 1
			endif
			let depth += 1
		else
			let depth -= 1
			if depth == 0
				call add(tree, LatexBox_TexToTree(strpart(a:str, i1, i2 - i1)))
				let i1 = i2 + 1
			endif
		endif
	endwhile
	return tree
endfunction
" }}}

" Tree To Tex {{{
function! LatexBox_TreeToTex(tree)
	if type(a:tree) == type('')
		return a:tree
	else
		return '{' . join(map(a:tree, 'LatexBox_TreeToTex(v:val)'), '') . '}'
	endif
endfunction
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
