" Vim global plugin for git blame and git grep
" defines the following global commands
"
"   Blame - runs git blame on the file of the current window; The result is displayed in a scratch buffer; cursor is set to the same position as the original buffer.
"              While in the blame window: Blame opens another scratch window  with the commit that changed the current line.
"
"   GitGrep  - Grep in all files under git - from current directory down. Search results are put int o the quickfix window. 
"
" Last Change:  2020 June
" Maintainer:   Michael Moser <https://github.com/mosermichael>
" License:      This file is placed in the public domain.
"
"
if exists("g:loaded_gitblameutil")
  finish
endif
let g:loaded_gitblameutil = 1

if !exists(":GitGrep")
command! -nargs=* GitGrep call s:RunGitGrep()
endif

" Character to use to quote patterns and filenames before passing to grep.
if !exists("Grep_Shell_Quote_Char")
    if has("win32") || has("win16") || has("win95")
        let Grep_Shell_Quote_Char = ''
    else
        let Grep_Shell_Quote_Char = "'"
    endif
endif


" copied from here: https://gist.github.com/romainl/eae0a260ab9c135390c30cd370c20cd7
function! s:Redir(cmd, rng, start, end)
	for win in range(1, winnr('$'))
		if getwinvar(win, 'scratch')
			execute win . 'windo close'
		endif
	endfor
	if a:cmd =~ '^!'
		let s:cmd = a:cmd =~' %'
			\ ? matchstr(substitute(a:cmd, ' %', ' ' . expand('%:p'), ''), '^!\zs.*')
			\ : matchstr(a:cmd, '^!\zs.*')
		if a:rng == 0
			let s:output = systemlist(s:cmd)
		else
			let s:joined_lines = join(getline(a:start, a:end), '\n')
			let s:cleaned_lines = substitute(shellescape(s:joined_lines), "'\\\\''", "\\\\'", 'g')
			let s:output = systemlist(s:cmd . " <<< $" . s:cleaned_lines)
		endif
	else
		redir => s:output
		execute a:cmd
		redir END
		let  s:output = split(s:output, "\n")
	endif
	vnew
	let w:scratch = 1
	setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
	call setline(1, s:output)

    let s:rename="file " . s:cmd
    execute s:rename
endfunction

command! -nargs=1 -complete=command -bar -range Redir silent call s:Redir(<q-args>, <range>, <line1>, <line2>)

function! s:RunGitGrep()
   " --- No argument supplied. Get the identifier and file list from user ---
    let pattern = input("Grep for pattern: ", expand("<cword>"))
    if pattern == ""
        return
    endif
    let pattern = g:Grep_Shell_Quote_Char . pattern . g:Grep_Shell_Quote_Char


    let tmpfile = tempname()
    let grepcmd = 'git grep -n ' . pattern . " |  tee " . tmpfile

    " --- run grep command ---
    let cmd_output = system(grepcmd)

    if cmd_output == ""
        echohl WarningMsg |
        \ echomsg "Error: Pattern " . pattern . " not found" |
        \ echohl None
        return
    endif

    " --- put output of grep command into message window ---
    let old_efm = &efm
    set efm=%f:%l:%m

   "open search results, but do not jump to the first message (unlike cfile)
   "execute "silent! cfile " . tmpfile
    execute "silent! cgetfile " . tmpfile

    let &efm = old_efm

    "botright copen
    OpenQuickFix

    call delete(tmpfile)

endfunction

function!  s:OpenQuickFix()
	let size = &lines
	let size = size / 3
	execute 'copen \| resize ' . size . '"'
endfunction

if !exists(":OpenQuickFix")
command! -nargs=* OpenQuickFix call s:OpenQuickFix()
endif


if !exists(":Blame")
command! -nargs=* Blame call s:RunGitBlame()
endif

function! GitBlameGlobalShowCommit()

            let s:curline = getline('.')
            let s:eofhash = stridx(s:curline,' ')
            let s:hash = strpart(s:curline,0,s:eofhash)

            let s:firsthashchar=strpart(s:hash,0,1)
            if s:firsthashchar == "^"
                let s:hash = strpart(s:hash,1)
            endif    

            let s:cmd = "git show " . s:hash

            let  s:output = systemlist(s:cmd)

            belowright new
            let w:scratch = 1
            setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
            call setline(1, s:output)

            let s:rename="file " . s:cmd

            setlocal nomodifiable

endfunction

function! s:RunGitBlame()

    let s:file=expand('%:p')
    let s:lineNum=line('.')

    if s:file != "" 


        let s:cmdcheck=s:file[0:8]
        if s:cmdcheck == "git blame"

            call GitBlameGlobalShowCommit()

        else     

            let s:cmd="Redir !git blame " . expand('%:p') 
            execute s:cmd
            let s:linecmd="normal ". s:lineNum . "gg"
            execute s:linecmd

            let s:curline = getline('.')
            let s:pos = stridx(s:curline,')')
            let s:pos = s:pos + 3

            call cursor(s:lineNum, s:pos)

            "zoom the window, to make it full screen
            exec "normal \<C-W>\|\<C-W>_"

            noremap <buffer> <silent> <CR>        :call GitBlameGlobalShowCommit()<CR>

            setlocal nomodifiable

        endif
    else
        echo "Error: current buffer must be a file"
    endif        
endfunction

if !exists(":GitLs")
command! -nargs=* GitLs call s:RunGitLs()
endif

function! s:RunGitLs()

    let tmpfile = tempname()
    let grepcmd = "git ls-files  |  tee " . tmpfile

    " --- run grep command ---
    let cmd_output = system(grepcmd)

    if cmd_output == ""
        echohl WarningMsg |
        \ echomsg "Error: current directory must be a git repository" |
        \ echohl None
        return
    endif

    " --- put output of grep command into message window ---
    let old_efm = &efm
    set efm=%f

   "open search results, but do not jump to the first message (unlike cfile)
   "execute "silent! cfile " . tmpfile
    execute "silent! cgetfile " . tmpfile

    let &efm = old_efm

    let h = winheight(0)

    "botright copen \| vertical resize 
    OpenQuickFix

    call delete(tmpfile)

endfunction

if !exists(":Graph")
command! -nargs=* Graph call s:RunGitGraph()
endif

function! GitGraphGlobalShowCommit()
        let s:curline = getline('.')
        let s:starthash = stridx(s:curline,'\')+1
        let s:eofhash = stridx(s:curline, ' ', s:starthash) - s:starthash

        let s:hash = strpart(s:curline,s:starthash, s:eofhash)

        let s:firsthashchar=strpart(s:hash,0,1)
        if s:firsthashchar == "^"
            let s:hash = strpart(s:hash,1)
        endif    

        let s:cmd = "git show " . s:hash

        let  s:output = systemlist(s:cmd)

        belowright new
        let w:scratch = 1
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
        call setline(1, s:output)

        let s:rename="file " . s:cmd 
        setlocal nomodifiable
endfunction

function! s:RunGitGraph()

    let s:file=expand('%:p')

    let s:idx = stridx(s:file, "git log --graph")
    if s:idx != -1

        call GitGraphGlobalShowCommit()
        
    else        
       let s:cmd="Redir !git log --graph --full-history --all --pretty=format:'\\%h \\%an \\%s'"
       execute s:cmd 

       noremap <buffer> <silent> <CR>        :call GitGraphGlobalShowCommit()<CR>

       setlocal nomodifiable
    endif

endfunction

"======================================================
" run git diff
"======================================================

if !exists(":GitDiff")
command! -nargs=* GitDiff call s:RunGitDiff()
endif

" has to be global function. strange.
function! GitDiffGlobalShowDiff()
    let s:line = getline(".")
    let s:tmpfile = tempname()


    let s:cmd="git show :" . s:line  . " >" . s:tmpfile

    call system(s:cmd)

    "aboveleft new 
    tabnew

    file "git diff " . s:line

    execute "silent edit " . s:line
    execute "silent vertical diffs " . s:tmpfile

    let s:rename="silent file git diff " . s:line
    execute s:rename

    setlocal nomodifiable

    call delete(s:tmpfile)
endfunction



function! s:RunGitDiff()
 
    let s:cmd="git diff --name-only"

    " --- run grep command ---
    let s:output = systemlist(s:cmd)

    belowright new 

    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
    call setline(1, s:output)

    noremap <buffer> <silent> <CR>        :call GitDiffGlobalShowDiff()<CR>
    setlocal nomodifiable

endfunction



