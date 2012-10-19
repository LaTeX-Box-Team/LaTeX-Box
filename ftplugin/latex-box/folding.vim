" Folding support for LaTeX
"
" Options
" g:LatexBox_Folding       - Turn on/off folding
" g:LatexBox_fold_parts    - Define which sections and parts to fold
" g:LatexBox_fold_envs     - Turn on/off folding of environments
" g:LatexBox_fold_preamble - Turn on/off folding of preamble
"

" {{{1 Set options
if exists('g:LatexBox_Folding')
    setl foldmethod=expr
    setl foldexpr=LatexBox_FoldLevel(v:lnum)
    setl foldtext=LatexBox_FoldText(v:foldstart)
endif
if !exists('g:LatexBox_fold_preamble')
    let g:LatexBox_fold_preamble=1
endif
if !exists('g:LatexBox_fold_envs')
    let g:LatexBox_fold_envs=1
endif
if !exists('g:LatexBox_fold_parts')
    let g:LatexBox_fold_parts=[
                \ "part",
                \ "chapter",
                \ "section",
                \ "subsection",
                \ "subsubsection"
                \ ]
endif

" {{{1 LatexBox_FoldLevel
function! LatexBox_FoldLevel(lnum)
    let line  = getline(a:lnum)

    " Fold preamble
    if exists('g:LatexBox_fold_preamble')
        if line =~ '\s*\\documentclass'
            return ">1"
        endif
        if line =~ '\s*\\begin{document}'
            return "<1"
        endif
    endif

    " Fold parts and sections
    let level = 1
    for part in g:LatexBox_fold_parts
        if line  =~ '^\s*\\' . part . '\*\?{'
            return ">" . level
        endif
        let level += 1
    endfor

    " Fold environments
    if exists('g:LatexBox_fold_envs')
        if line =~ '\\begin{.*}'
            return "a1"
        endif
        if line =~ '\\end{.*}'
            return "s1"
        endif
    endif

    return "="
endfunction

" {{{1 LatexBox_FoldText
function! LatexBox_FoldText(lnum)
    let line = getline(a:lnum)

    " Define pretext
    let pretext = '    '
    if v:foldlevel == 1
        let pretext = '>   '
    elseif v:foldlevel == 2
        let pretext = '->  '
    elseif v:foldlevel == 3
        let pretext = '--> '
    elseif v:foldlevel >= 4
        let pretext = printf('--%i ',v:foldlevel)
    endif

    " Preamble
    if line =~ '\s*\\documentclass'
        return pretext . "Preamble"
    endif

    " Parts and sections
    if line =~ '\\\(\(sub\)*section\|part\|chapter\)'
        return pretext .  matchstr(line,
                    \ '^\s*\\\(\(sub\)*section\|part\|chapter\)\*\?{\zs.*\ze}')
    endif

    " Environments
    if line =~ '\\begin'
        let env = matchstr(line,'\\begin\*\?{\zs\w*\*\?\ze}')
        let label = ''
        let caption = ''
        let i = v:foldstart
        while i <= v:foldend
            if getline(i) =~ '^\s*\\label'
                let label = ' (' . matchstr(getline(i),
                            \ '^\s*\\label{\zs.*\ze}') . ')'
            end
            if getline(i) =~ '^\s*\\caption'
                let env .=  ': '
                let caption = matchstr(getline(i),
                            \ '^\s*\\caption\(\[.*\]\)\?{\zs.\{1,30}')
                let caption = substitute(caption, '}\s*$', '','')

            end
            let i += 1
        endwhile
        return pretext . printf('%-12s', env) . caption . label
    endif

    " Not defined
    return "Fold text not defined"
endfunction

" {{{1 Footer
" vim:fdm=marker:ff=unix:ts=4:sw=4
