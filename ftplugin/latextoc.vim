" Settings {{{
setlocal buftype=nofile
            \ bufhidden=wipe
            \ nobuflisted
            \ noswapfile
            \ nowrap
            \ cursorline
            \ nonumber
            \ nolist
            \ tabstop=8
            \ cole=0
            \ cocu=nvic
" }}}

" Functions {{{
function! s:TOCToggleNumbers()
    if b:toc_numbers
        setlocal conceallevel=3
        let b:toc_numbers = 0
    else
        setlocal conceallevel=0
        let b:toc_numbers = 1
    endif
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

" Mappings {{{
noremap <buffer> <silent> s :call <SID>TOCToggleNumbers()<CR>
noremap <buffer> <silent> q :bwipeout<CR>
noremap <buffer> <silent> <Esc> :bwipeout<CR>
noremap <buffer> <silent> <Space> :call <SID>TOCActivate(0)<CR>
noremap <buffer> <silent> <CR> :call <SID>TOCActivate(1)<CR>
nnoremap <silent> <buffer> <leftrelease> :call <SID>TOCActivate(0)<cr>
nnoremap <silent> <buffer> <2-leftmouse> :call <SID>TOCActivate(1)<cr>
nnoremap <buffer> <silent> G G4k
noremap <buffer> <silent> OA k
noremap <buffer> <silent> OB j
noremap <buffer> <silent> OC l
noremap <buffer> <silent> OD h
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
