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

        let s:tokens = split(s:curline, " ")
        let s:token = ""
        let s:hash = ""

        for s:token in s:tokens
            if s:token != '|' && s:token != '*' && s:token != '\' && s:token !=  '/'
                let s:hash = s:token
                break
            endif
        endfor
        

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
       let s:cmd='Redir !git log --graph --full-history --all --pretty=format:' . "'" . '%h \%an: (%ci) \%s' .  "'"
       silent! execute s:cmd 

       noremap <buffer> <silent> <CR>        :call GitGraphGlobalShowCommit()<CR>

       setlocal nomodifiable
    endif

endfunction


function! s:Chomp(string)
    return substitute(a:string, '\n\+$', '', '')
endfunction


"======================================================
" run git diff
"======================================================

if !exists(":GitDiff")
command! -nargs=* GitDiff call s:RunGitDiff(<f-args>)
endif

" has to be global function. strange.
function! GitDiffGlobalShowDiff()
    let s:line = getline(".")
    let s:tmpfile = tempname()

    "aboveleft new 
    tabnew

    let s:git_top_dir = s:Chomp( system("git rev-parse --show-toplevel") )

    call chdir(s:git_top_dir)

    file "git show :" . s:line

    if s:GitDiffGlobalShowDiff_from_commit == ""
        execute "silent edit " . s:line

        let s:rename ="silent file [local]"
        execute s:rename

    else
        let s:show_cmd = "git show  " . s:GitDiffGlobalShowDiff_from_commit . ":" . s:line
        let s:cmd =  s:show_cmd . " >" . s:tmpfile
        call system(s:cmd)
        execute "silent edit " . s:tmpfile
        call delete(s:tmpfile)

        let s:rename ="silent file " .  s:GitDiffGlobalShowDiff_from_commit . ":" . s:line
        execute s:rename
        
        setlocal nomodifiable
    endif

    let s:top_hash = s:GitDiffGlobalShowDiff_to_commit
    if s:top_hash == ""
       let s:top_hash = s:Chomp( system("git rev-parse --short HEAD") )
    endif
 
    let s:show_cmd = "git show  " . s:GitDiffGlobalShowDiff_to_commit . ":" . s:line
    let s:cmd= s:show_cmd . " >" . s:tmpfile

    call system(s:cmd)
    execute "silent vertical diffs " . s:tmpfile
    call delete(s:tmpfile)

   
    let s:rename="silent file " . s:top_hash  . ":" . s:line
    execute s:rename
    
    setlocal nomodifiable

    call chdir("-")

endfunction




function! s:RunGitDiff(...)
 
    setlocal modifiable
    let s:GitDiffGlobalShowDiff_from_commit = ""
    let s:GitDiffGlobalShowDiff_to_commit = ""
    let s:to_commit = ""
    if len(a:000) == 2
        let s:GitDiffGlobalShowDiff_from_commit = a:1
        let s:GitDiffGlobalShowDiff_to_commit = a:2
    else
      if len(a:000) == 1
        let s:GitDiffGlobalShowDiff_to_commit = a:1
      endif
    endif

    let s:cmd="git diff --name-only  " . s:GitDiffGlobalShowDiff_from_commit . " " . s:GitDiffGlobalShowDiff_to_commit

    " --- run grep command ---
    let s:output = systemlist(s:cmd)

    belowright new 

    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
    call setline(1, s:output)

    noremap <buffer> <silent> <CR>        :call GitDiffGlobalShowDiff()<CR>
    setlocal nomodifiable


endfunction


if !exists(":GitLog")
command! -nargs=* GitLog call s:RunGitLog()
endif

function! GitLogGlobalShowLog()

    let s:topline = line('.')

    while s:topline > 0

        let s:curline = getline(s:topline)
        let s:topline = s:topline - 1

        let s:tok = split(s:curline)
        if len(s:tok) != 0 && s:tok[0] == "commit"
                let s:cmd = "git show " . s:tok[1]

                let  s:output = systemlist(s:cmd)

                belowright new
                let w:scratch = 1
                setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
                call setline(1, s:output)

                let s:rename="file " . s:cmd

                setlocal nomodifiable
                return
        endif

    endwhile
endfunction


function! s:RunGitCommand(command, actionFunction, title)
        let s:tmpfile = tempname()

        let s:cmd =  a:command . " >" . s:tmpfile
        call system(s:cmd)
        execute "silent edit " . s:tmpfile
        call delete(s:tmpfile)

        let s:rename ="silent file " . a:title
        execute s:rename
       
        let s:cmd = "noremap <buffer> <silent> <CR>        :call " . a:actionFunction . "()<CR>"
        exec s:cmd
        setlocal nomodifiable
endfunction   

function! s:RunGitLog()
        call s:RunGitCommand("git log --name-status --find-renames", "GitLogGlobalShowLog", "git\\ log")
endfunction


function! GitBranchGlobalChooseBranch()

        let s:title=bufname()  "expand('%:p')

        let s:tokens = split(s:title, " ")
    
        let s:curline = getline('.')
        let s:curline = s:Chomp( s:curline )

        if s:tokens[0] == "remote"
            let s:toks = split(s:curline, "/")
            let s:localbr = s:toks[-1]
            call system( "git rev-parse " . s:localbr)

            if  v:shell_error != 0
                let s:cmd = "git checkout " . s:curline . " -b " . s:localbr . " 2>&1"
            else 
                let s:cmd = "git checkout " . s:localbr . " 2>&1"
            endif

            let s:out = system(s:cmd)

        else 
            let s:cmd = "git checkout " . s:curline . " 2>&1"
            "echo  "cmd: " . s:cmd
            let s:out = system(s:cmd)

        endif

        if v:shell_error != 0 
            let s:lines = split(s:out, '\n')
            echo "Error: " . s:lines[0]
        else
            echo " "
            " force update of status line
            execute "let &stl=&stl"
        endif

endfunction

if !exists("BranchRemote")
command! -nargs=* BranchRemote call s:RunBranchRemote()
endif

function! s:RunBranchRemote() 
        call s:RunGitCommand("git branch --remote", "GitBranchGlobalChooseBranch", "remote\\ branches")
endfunction

if !exists("BranchLocal")
command! -nargs=* BranchLocal call s:RunBranchLocal()
endif

function! s:RunBranchLocal()
        call s:RunGitCommand("git branch | cut -c 2-", "GitBranchGlobalChooseBranch", "local\\ branches")
endfunction



"======================================================
" command to show git branch in status line
"======================================================

if !exists(":ShowGitBranchInStatusLine")
command! -nargs=* ShowGitBranchInStatusLine call s:ShowGitBranchInStatusLine()
endif

function! GitBlameStatusLineGitBranch() 
    let s:branch_name = trim(system("git branch 2>/dev/null | grep '*' | tail -c +2")) 
    if s:branch_name == ""
        return ""
    endif
    return '[' . s:branch_name . ']'
endfunction    
 

function! s:ShowGitBranchInStatusLine()

    set statusline=%f\ %h%w%m%r\ %=%(%l,%c%V\ %=\ %P%)\ %{GitBlameStatusLineGitBranch()}

    "always show status line
    set laststatus=2 

    "show cursor pos in status line
    set ruler

endfunction    

command! -nargs=* GitStatus call s:RunGitStatus()

function! GitStatusGlobalShowStatus()

   let s:topline = getline('.')
   let s:tokens = split(s:topline, " ")

   if len(s:tokens) != 0
     let s:fname = trim(s:Chomp(s:tokens[-1]))
     echo(s:fname)
     if filereadable(s:fname) || isdirectory(s:fname)
         let s:cmd = "silent! belowright new " . s:fname
         exec s:cmd
     endif
   endif
endfunction

function! s:RunGitStatus()
   call s:RunGitCommand("git status", "GitStatusGlobalShowStatus", "git\\ status")


endfunction



