if exists("gitblame_plugin_loaded")
    finish
endif
let gitblame_plugin_loaded = 1

"" Vim global plugin for git blame and git grep
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

function! s:GitCheckGitDir()
   let s:top_dir = s:Chomp( system("git rev-parse --show-toplevel") )
   if v:shell_error != 0
       echo "current directory not in a git repository"
       return ""
   endif
   return s:top_dir
endfunction

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
    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
       return
    endif

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
    let s:ccmdo = 'copen ' . size
    execute s:ccmdo
endfunction

if !exists(":OpenQuickFix")
command! -nargs=* OpenQuickFix call s:OpenQuickFix()
endif


if !exists(":Blame")
command! -nargs=* Blame call s:RunGitBlame()
endif


function! GitBlameGlobalShowCommit()

    let s:curline = getline('.')

    if stridx(s:curline, "(Not Committed Yet") == -1

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
    else
        call s:BeepNow()
    endif

endfunction


function! s:RunGitBlame()
    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
          return
    endif

    let s:file=expand('%:p')
    let s:lineNum=line('.')

    if s:file != "" 


        let s:cmdcheck=s:file[0:8]
        if s:cmdcheck == "git blame"

            call GitBlameGlobalShowCommit()

        else     
                    
             let s:cmd="git blame " . expand('%:p') 
            
             call s:RunGitCommand(s:cmd, "", "GitBlameGlobalShowCommit", s:cmd, 1)

             let s:linecmd="normal ". s:lineNum . "gg"
             execute s:linecmd

             let s:curline = getline('.')
             let s:pos = stridx(s:curline,')')
             let s:pos = s:pos + 3
             call cursor(s:lineNum, s:pos)
        endif
    else
        echo "Error: current buffer must be a file"
    endif        
endfunction



if !exists(":GitLs")
command! -nargs=* GitLs call s:RunGitLs()
endif

function! s:RunGitLs()

    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
       return
    endif

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
    let s:topline = line('.')
    while s:topline > 0

        let s:curline = getline(s:topline)
        let s:topline = s:topline - 1

        let s:tokens = split(s:curline)
        let s:token = ""
        let s:hash = ""

        for s:token in s:tokens
           if match(s:token,'^[0-9a-fA-F]*$') == 0
                let s:hash = s:token
                break
            endif
        endfor
 
        if s:hash == ''
            continue
        endif

        let s:firsthashchar=strpart(s:hash,0,1)
        if s:firsthashchar == "^"
            let s:hash = strpart(s:hash,1)
        endif    

        let s:cmd = "git show " . s:hash . " 2>/dev/null"

        call system(s:cmd)
        if  v:shell_error == 0

            let s:output = systemlist(s:cmd)
            "let s:output = 'line: ' . s:topline . ' cmd: ' . s:cmd 

            belowright new
            let w:scratch = 1
            setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
            call setline(1, s:output)

            let s:rename="file " . s:cmd 
            setlocal nomodifiable
            break
        endif
    endwhile
endfunction

function! s:RunGitGraph()

    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
       return
    endif

    let s:file=expand('%:p')

    let s:idx = stridx(s:file, "git log --graph")
    if s:idx != -1

        call GitGraphGlobalShowCommit()
        
    else        
       let s:cmd='git log --graph --full-history --all --pretty=format:' . "'" . '%h \%an: (%ci) \%s' .  "'"

       call s:RunGitCommand(s:cmd, "", "GitGraphGlobalShowCommit", "Git\ Graph", 1)
    endif

endfunction



function! s:Chomp(string)
    return substitute(a:string, '\n\+$', '', '')
endfunction

function! s:BeepNow()
    :set novisualbell
    :set errorbells
    :exe "normal \<Esc>"
endfunction


"======================================================
" run git diff
"======================================================

if !exists(":GitDiff")
command! -nargs=* GitDiff call s:RunGitDiff(<f-args>)
endif

if !exists(":GitDiffNoSpace")
command! -nargs=* GitDiffNoSpace call s:RunGitDiffNoSpace(<f-args>)
endif

" has to be global function. strange.
function! GitDiffGlobalShowDiff()
    let s:line = getline(".")
    let s:tmpfile = tempname()

    "aboveleft new 
    tabnew

    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
       return
    endif
 
    call chdir(s:git_top_dir)

    let s:line = strpart(s:line, 0, strridx(s:line,":"))

    file "git show :" . s:line

    if s:GitDiffGlobalShowDiff_from_commit == ""
        execute "silent edit " . s:line

        "let s:rename ="silent file [local]"
        "execute s:rename

    else
        let s:show_cmd = "git show  " . s:GitDiffGlobalShowDiff_from_commit . ":" . s:line
 
        let s:cmd =  s:show_cmd . " >" . s:tmpfile
        call system(s:cmd)
        execute "silent edit " . s:tmpfile
        call delete(s:tmpfile)

        let s:rename ="silent file " .  s:GitDiffGlobalShowDiff_from_commit
        execute s:rename
        
        setlocal nomodifiable
    endif

    let s:top_hash = s:GitDiffGlobalShowDiff_to_commit
    if s:top_hash == ""
       let s:top_hash = s:Chomp( system("git rev-parse --short HEAD") )
    endif
 
    let s:show_cmd = "git show  " . s:GitDiffGlobalShowDiff_to_commit . ":" . s:line
    let s:cmd= s:show_cmd . " >" . s:tmpfile

"    if s:GitDiffGlobalShowDiffMode != ""
"        let old_diffopt = &diffopt
"        execute "normal! set diffopt=iwhite,iblank,iwhiteall"
"    endif

    call system(s:cmd)

    if s:GitDiffGlobalShowDiffMode != ""
        execute "set diffopt=iwhite,iblank,iwhiteall | silent vertical diffs " . s:tmpfile
    else 
        execute "set diffopt=internal,filler,closeoff | silent vertical diffs " . s:tmpfile
    endif

    call delete(s:tmpfile)

   
    let s:rename="silent file " . s:top_hash 
    execute s:rename
    
    setlocal nomodifiable

"    if s:GitDiffGlobalShowDiffMode != ""
"        let &diffopt = old_diffopt 
"    endif
"
    call chdir("-")

endfunction

function! s:RunGitDiffNoSpace(...)
    call s:RunGitDiffImpl("--ignore-all-space", a:000)
endfunction
 

function! s:RunGitDiff(...)
    call s:RunGitDiffImpl("", a:000)
endfunction


function! s:RunGitDiffImpl(mode, ...)
 
"    echo "mode: " . a:mode " f-args: " . type(a:1) . " : " . len(a:1) . " :: " . join(a:1,';')
"    return

    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
         return
    endif

    setlocal modifiable
    let s:GitDiffGlobalShowDiff_from_commit = ""
    let s:GitDiffGlobalShowDiff_to_commit = ""
    let s:to_commit = ""
    if len(a:1) == 2
        let s:GitDiffGlobalShowDiff_from_commit = a:1[0]
        let s:GitDiffGlobalShowDiff_to_commit = a:1[1]
    else
      if len(a:1) == 1
        let s:GitDiffGlobalShowDiff_to_commit = a:1[0]
      endif
    endif

    let s:GitDiffGlobalShowDiffMode = a:mode

   "let s:cmd=  "git diff --name-only "  . s:GitDiffGlobalShowDiff_from_commit . " " . s:GitDiffGlobalShowDiff_to_commit
   "let s:cmd=  "git diff --name-status " . s:GitDiffGlobalShowDiff_from_commit . " " . s:GitDiffGlobalShowDiff_to_commit . " | awk '{ print $2 \": \" $1 }'" 
    let s:cmd=  "git diff --name-status " . a:mode . " " . s:GitDiffGlobalShowDiff_from_commit . " " . s:GitDiffGlobalShowDiff_to_commit 
 
    
    let s:res = systemlist(s:cmd)
    if len(s:res) == 0
        if s:GitDiffGlobalShowDiff_from_commit == "" && s:GitDiffGlobalShowDiff_to_commit == ""
            echo "No changes between working tree and index"
        else
            echo "No changes between the two working trees"
        endif
        return
    endif

    let s:status_names = { 'A' : 'Added', 'C' : 'Copied', 'D' : 'Deleted', 'M' : 'Modified', 'R' : 'Renamed', 'T' : 'Changed', 'U' : 'Unmerged', 'X' : 'Unknown', 'B' : '[pairing Broken]', '*' : '[all or one]' }
    let s:report = ""
    for s:line in s:res
        let s:tokens = split(s:line,"\t")
        let s:status = ""
        
        if a:mode != ""
            let s:diff_check = system("git diff -w --ignore-blank-lines " . s:tokens[1])
            if s:diff_check == ""
                continue
            endif
        endif

        for s:item in split(s:tokens[0], '\zs')
            if match(s:item,'\d') != -1
               continue
            endif  
            let s:status = s:status . s:status_names[ s:item ] . ' '
        endfor
        let s:report = s:report . s:tokens[1] . ": " . s:status . "  " . s:tokens[0] . "\n"
    endfor

    let s:title = "git\ diff\ " . a:mode . " " . s:GitDiffGlobalShowDiff_from_commit . "\ " . s:GitDiffGlobalShowDiff_to_commit

    call s:RunGitCommand("", s:report, "GitDiffGlobalShowDiff", s:title, 1) ", "%f:%m")

endfunction


if !exists(":GitLog")
command! -nargs=* GitLog call s:RunGitLog("")
endif

if !exists(":GitLogF")
command! -nargs=* -complete=file GitLogF call s:RunGitLog(<f-args>)
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

function! s:RunGitCommand(command, msg, actionFunction, title, newBuffer)

        if winnr('$') > 1
            for win in range(1, winnr('$'))
                if getwinvar(win, 'gitcmdwnd')
                    execute  win . 'windo close'
                    "execute  win . "close!"
                endif
            endfor
        endif

        let s:git_top_dir = s:GitCheckGitDir()
        if s:git_top_dir == ""
          return
        endif

        let s:tmpfile = tempname()

        if a:msg == ""
            let s:cmd =  a:command . " >" . s:tmpfile
            call system(s:cmd)
        else 
            call writefile( split(a:msg,"\n"), s:tmpfile, "s")
        endif

        if a:newBuffer != 0
            new
        endif

       "let old_efm = &efm
       "set efm=errfmt
       "execute "silent! cgetfile " . s:tmpfile
        execute "silent 1,$d|0r " . s:tmpfile
       "let &efm = old_efm

        call delete(s:tmpfile)

        let s:rename ="silent file " . a:title
        execute s:rename
       
        "setlocal buftype=nofile nobuflisted noswapfile
        setlocal buftype=nofile noswapfile

        let w:gitcmdwnd = 1

        let s:cmd = "silent noremap <buffer> <silent> <CR>        :call " . a:actionFunction . "()<CR>"
        exec s:cmd
        set nomodified
        setlocal nomodifiable
endfunction   

function! s:RunGitLog(fileName)
        let s:cmd = "git log  --decorate --name-status --find-renames"

        if a:fileName != ""
            let s:cmd = s:cmd . " " . a:fileName
        endif

        call s:RunGitCommand(s:cmd, "", "GitLogGlobalShowLog", "git\\ log", 1) ", "%f")
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
        call s:RunGitCommand("git branch --remote", "", "GitBranchGlobalChooseBranch", "remote\\ branches", 1)
endfunction

if !exists("BranchLocal")
command! -nargs=* BranchLocal call s:RunBranchLocal()
endif

function! s:RunBranchLocal()
        call s:RunGitCommand("git branch | cut -c 2-", "", "GitBranchGlobalChooseBranch", "local\\ branches", 1)
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
    
   let s:git_top_dir = s:GitCheckGitDir()
   if s:git_top_dir == ""
       return
   endif
   call chdir(s:git_top_dir)

   let s:topline = getline('.')
   let s:tokens = split(s:topline, " ")

   if len(s:tokens) != 0
     let s:fname = trim(s:Chomp(s:tokens[-1]))
     if filereadable(s:fname) || isdirectory(s:fname)

         " check if the file is tracked.
         let s:cmd = "git ls-files --error-unmatch " . s:fname
         call system(s:cmd)

         if v:shell_error != 0 
            " can't get the file status, this is an untracked file
            let s:cmd = "silent! belowright new " . s:fname
            exec s:cmd
         else 

            let s:cmd = "silent edit ". s:fname 

            let s:top_hash = trim( s:Chomp( system("git rev-parse --short HEAD") ) )
            let s:show_cmd = "git show  " . s:top_hash . ":" . s:fname
            let s:tmpfile = tempname()
            let s:cmd_git_show = s:show_cmd . " >" . s:tmpfile

            tabnew

            execute s:cmd
            let s:rename ="silent file [local]"
            execute s:rename
            setlocal nomodifiable


            call system(s:cmd_git_show)
            execute "silent vertical diffs " . s:tmpfile
            call delete(s:tmpfile)
            let s:rename="silent file " . s:top_hash  . ":" . s:fname
            execute s:rename
            setlocal nomodifiable
 
        endif
     endif
   endif

   call chdir("-")

endfunction

function! s:RunGitStatusImp(replace)

   let s:git_top_dir = s:GitCheckGitDir()
   if s:git_top_dir == ""
       return
   endif

   let s:git_top_dir = s:GitCheckGitDir()
   if s:git_top_dir == ""
       return
   endif

   call chdir(s:git_top_dir)
   let save_a_mark = getpos(".")

   call s:RunGitCommand("git status", "", "GitStatusGlobalShowStatus", "git\\ status", a:replace)
 
   call setpos(".", save_a_mark)
   call chdir("-")
endfunction

function! s:RunGitStatus()
    call s:RunGitStatusImp(1)
endfunction

command! -nargs=* Stage call s:RunGitStage()
command! -nargs=* StageAll call s:RunGitStageAll()
command! -nargs=* Unstage call s:RunGitUnStage()
command! -nargs=* UnstageAll call s:RunGitUnStageAll()

function! s:RunGitStageImp(cmdArg,addCurrent)
    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
         return
    endif

    call chdir(s:git_top_dir)
    let s:file=bufname()
    let s:cmdcheck=s:file[0:10]

    if s:cmdcheck == "git status"

        if a:addCurrent != 0
            let s:topline = getline('.')
            let s:tokens = split(s:topline, " ")
            let s:fname = trim(s:Chomp(s:tokens[-1]))
            if filereadable(s:fname) || isdirectory(s:fname)
                let s:cmdgs = a:cmdArg . ' ' .s:fname
            else
                echo "Current line doe not mention a file"
                call chdir("-")
                return
            endif
        else
            let s:cmdgs = a:cmdArg
        endif

        call system(s:cmdgs)
        if  v:shell_error == 0
            setlocal modifiable

            " refresh the current window.
            call s:RunGitStatusImp(0)

            setlocal nomodifiable

            let s:msg = "command: " . s:cmdgs . " succeeded"
            echo s:msg
        else
            let s:msg = "command: " . s:cmdgs . " failed"
            echo s:msg
        endif

    else
        echo "You must be in buffer creaed by GitStatus command"
    endif
    call chdir("-")
endfunction

function! s:RunGitStage()
    call s:RunGitStageImp('git add', 1)
endfunction

function! s:RunGitUnStage()
    call s:RunGitStageImp('git restore --staged', 1)
endfunction

function! s:RunGitStageAll()
    call s:RunGitStageImp('git add -u', 0)
endfunction


function! s:RunGitUnStageAll()
    call s:RunGitStageImp('git reset', 0)   
endfunction

if !exists(":CdTopDir")
command! -nargs=* CdTopDir call s:RunChangeTopDir()
endif

function! s:RunChangeTopDir()
    let s:git_top_dir = s:GitCheckGitDir()
    if s:git_top_dir == ""
        echo "Error: current directory not in a git repository"
    else
        call chdir(s:git_top_dir)
        echo "new current directory: " . s:git_top_dir
    endif
endfunction



