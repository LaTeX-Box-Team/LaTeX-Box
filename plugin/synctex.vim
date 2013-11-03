if ! g:LatexBox_enable_synctex
	finish
endif

" This function is needed because synctex adds an addition "./" in the path
" and standard "vim --remote +line file" syntax cannot be used as a
" consequence
function! LatexBox_Synctex_Backward(path,line)
	let l:swb=&switchbuf
	let &switchbuf="useopen,usetab"
	let l:file=substitute(a:path,"\\./","","")
	if buflisted(l:file)
		let l:open = "sbuffer"
	else
		let l:open = "split"
	endif
	silent execute l:open . " " . l:file
	execute "normal! " . a:line . "Gzv"
	let &switchbuf=l:swb
endfunction

