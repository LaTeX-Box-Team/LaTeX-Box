" Latex Box synctex support
if ! g:LatexBox_enable_synctex
	finish
endif

if ! exists("g:LatexBox_synctex_viewer")
	if has("macunix")
		let g:LatexBox_synctex_viewer = "skim"
	elseif has("unix")
		if executable("zathura")
			let g:LatexBox_synctex_viewer = "zathura"
		else
			let g:LatexBox_synctex_viewer = "evince"
		endif
	endif
endif

let s:plugin_path = expand('<sfile>:p:h')

function LatexBox_Synctex_Forward()
	if g:LatexBox_synctex_viewer == "zathura" || g:LatexBox_synctex_viewer == "evince"
		"For both viewers, we use the 'synctex' executable to provide
		"the right page
		let cmd="synctex view -i " . line('.') . ":0:" . expand("%:p") . " -o " . LatexBox_GetOutputFile()
		if g:LatexBox_synctex_viewer == "zathura"
			let cmd .= " -x " . shellescape(s:plugin_path . "/synctex-zathura.sh " . v:progname . " " . v:servername . " %{page+1} %{output}",1) 
		elseif g:LatexBox_synctex_viewer == "evince"
			let cmd .= " -x " . shellescape('evince -i %{page+1} %{output}',1) 
		endif
		silent execute "!" . cmd . " &"
	else
		echoerr "LatexBox has no Synctex implementation for your platform"
	endif
endfunction

command! LatexForwardSearch call LatexBox_Synctex_Forward()
