if exists("g:loaded_libvim_misc") || &cp || v:version < 700
    finish
endif
let g:loaded_libvim_misc = 1

"----------------------------------------------------------------
function! misc#CheckResult(result, msg)
    if(a:result != 0)
        echohl WarningMsg | echo a:msg | echohl None
        return -1
    endif
    return 0
endfunction

"----------------------------------------------------------------
function! misc#CheckParamsNotEmpty(...)
    for l:var in a:000
        if(empty(l:var))
            return -1
        endif
    endfor
    return 0
endfunction

"----------------------------------------------------------------
function! misc#Log(msg)
    if(g:debug_log)
        let l:msg = printf("[%s](%s) %s", strftime('%Y-%m-%d %H:%M:%S'), expand("%:p:h"), a:msg)
        call writefile([l:msg], g:log_file, 'a')
    endif
endfunction

"----------------------------------------------------------------
function! misc#BuildCommand(...)
    let cmd = ''
    for l:var in a:000
        let cmd = cmd . ' ' . l:var
    endfor
    return cmd
endfunction

"----------------------------------------------------------------
"SshCmd
function! misc#SshCmd(user, remoteAddr, remotePort, proxyAddr, identityFile, cmd)
    let ssh_cmd = "ssh "
    if(filereadable(a:identityFile))
        let identity = path#ConvertToCygPath(a:identityFile)
        let fmt = "-i %s "
        if(!empty(a:proxyAddr))
            let fmt = "-i %s -o \"ProxyCommand=nc -X connect -x %s \%h \%p\" "
        endif
        let ssh_cmd = ssh_cmd . printf(fmt, identity, proxyAddr)
    endif
    
    let ssh_cmd = ssh_cmd . printf(" -p %d %s@%s %s", a:remotePort, a:user, a:remoteAddr, a:cmd)
    call misc#RunCommand(cmd)
    return 0
endfunction

"----------------------------------------------------------------
" Shell command
function! misc#RunCommandInWindow(cmdline)
    botright new

    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal noswapfile
    setlocal nowrap
    setlocal filetype=shell
    setlocal syntax=shell
    nnoremap <buffer> <esc> :q<cr>
    nnoremap <buffer> q :q<cr>
    autocmd BufLeave <buffer> wincmd p

    call setline(1, a:cmdline)
    call setline(2, substitute(a:cmdline, '.', '=', 'g'))
    execute 'silent $read !' . escape(a:cmdline, '%#')
    setlocal nomodifiable
endfunction

"----------------------------------------------------------------
"RunCommand
function! misc#RunCommand(cmdline)
    let output = system(cmdline)
    call misc#Log(output)
endfunction

"----------------------------------------------------------------
function! misc#Zip(path, outputPath, exclude)
    if(!ingo#fs#path#Exists(a:path))
        echohl WarningMsg | echo a:path . ' not exists' | echohl None
        return -1
    endif
    if(ingo#fs#path#Exists(a:outputPath))
        echohl WarningMsg | echo a:outputPath . ' exists' | echohl None
        return -1
    endif

    let zipdir = path#ConvertToCygPath(a:path)
    let zipfile = path#ConvertToCygPath(a:outputPath)
    let exclude =  " * -x  '*.so' '*.so.*' '*.a' '*tags' '*cscope.files' '*cscope.out' " . a:exclude
    let cmd = printf('!bash -c "pushd ''%s''; zip -r ''%s'' %s; popd"', zipdir, zipfile, exclude)
    call misc#Log(cmd)
    silent exec cmd
    return 0
endfunction

"----------------------------------------------------------------
function! misc#DeleteCtagsAndCscopeFiles(path)
    let path = path#ConvertToWinPath(a:path)
    let ctags_file = path#ConvertToWinPath(ingo#fs#path#Combine(path, 'tags'))
    let cscope_file = path#ConvertToWinPath(ingo#fs#path#Combine(path, 'cscope.files'))
    let cscope_out = path#ConvertToWinPath(ingo#fs#path#Combine(path, 'cscope.out'))
    if filereadable(ctags_file)
        call misc#CheckResult(delete(ctags_file), "file to delete ctags")
    endif

    silent execute "cs kill -1"
    if filereadable(cscope_file)
        call misc#CheckResult(delete(cscope_file), "file to delete cscope file")
    endif
    if filereadable(cscope_out)
        call misc#CheckResult(delete(cscope_output), "file to delete cscope out")
    endif
endfunction

"----------------------------------------------------------------
function! misc#DoCtagsAndCscope(path, type, options)
    let current_dir = getcwd()
    let cyg_path = path#ConvertToCygPath(a:path)
    let win_path = path#ConvertToWinPath(a:path)
    execute ":cd ". win_path
    call misc#DeleteCtagsAndCscopeFiles(win_path)
    let l:findPara = ''
    let l:ctagsPara = ''
    if a:type ==# 'cpp'
        let l:ctagsPara =  ' --c++-kinds=+p+l+x --fields=+iaS --extras=+q -L '
        if(get(a:options, 'ExcludeBoost', 1))
            let l:findPara = " -path '*boost*' -prune -o"
        endif
        let l:findPara = l:findPara." -regex \".*\\.\\(h\\|c\\|cpp\\|cc\\|hpp\\)\" -print"
    elseif a:type ==# 'go'
        let l:ctagsPara = ' --fields=+afmikKlnsStzZ --extras=+q -L '
        if(get(a:options, 'ExcludeVender', 1))
            let l:findPara = " -path '*vendor*' -prune -o"
        endif
        let l:findPara = l:findPara." -name '*_test.go' -o -name '*.go' -print"
    elseif a:type ==# 'js'
        let l:ctagsPara = ' --fields=+nksSaf -V --language-force=javascript --javascript-kinds=vCcgpmf -L '
        if(get(a:options, 'ExcludeModules', 1))
            let l:findPara = " -path '*node_modules*' -prune -o"
        endif
        let l:findPara = l:findPara." -name '*.js' -o -name '*.html' "
    elseif a:type ==# 'php'
        let l:ctagsPara = ' --exclude=".svn" --exclude=".git" --totals=yes --tag-relative=yes --regex-PHP="/abstract\s+class\s+([^ ]+)/\1/c/" --regex-PHP="/interface\s+([^ ]+)/\1/c/" --regex-PHP="/(public\s+|static\s+|protected\s+|private\s+)\$([^ =]+)/\2/p/" --regex-PHP="/const\s+([^ =]+)/\1/d/" --regex-PHP="/final\s+(public\s+|static\s+|abstract\s+|protected\s+|private\s+)function\s+\&?\s*([^ (]+)/\2/f/" --PHP-kinds=+cfpd --extras=+q -L '
        let l:findPara = l:findPara." -name '*.js' -o -name '*.php' -o -name '*.html' -print"
    elseif a:type ==# 'python'
        let l:ctagsPara = ' --python-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v+i --fields=+iaS --extras=+q -L '
        let l:findPara = l:findPara." -name '*.py' -print"
    endif
    let cmd = misc#BuildCommand(g:find_bin, cyg_path, l:findPara)

    let ret = path#ConvertToWinPath(system(cmd))
    let fileList = split(ret)
    " call append(line(".")-1, ret)
    let cscopefile = ingo#fs#path#Combine(win_path, "cscope.files")
    call writefile(fileList, cscopefile, "b")

    let l:ctagsCmd = misc#BuildCommand(g:ctags_bin, l:ctagsPara, cscopefile)
    let l:cscopeCmd = misc#BuildCommand(g:cscope_bin, " -Rbk -s " , win_path)

    call system(l:ctagsCmd)
    call system(l:cscopeCmd)
    " silent execute "normal :"
    if filereadable("cscope.out")
        silent execute "cs add cscope.out"
    endif
    execute ":cd ".current_dir
    " :set tags+=$VIMPROJ/vimlib/tags,$VIMPROJ/vimlib/linux/tags,$VIMPROJ/vimlib/unix_network_programming/tags
    " :set path+=$VIMPROJ/vimlib/cpp_src,$VIMPROJ/vimlib/linux/include,$VIMPROJ/vimlib/linux/include/sys/,$VIMPROJ/vimlib/unix_network_programming/
endfunction

"-------------------------------------------------------------------------------------------------
function! misc#AstyleFile(file)
    let astyle_cmd = 'astyle.exe -A1Lfpjk3S --mode=c --ascii -n '
    let cmd = misc#BuildCommand(astyle_cmd, a:file)
    silent execute cmd
    silent exec 'normal :%s/\r//g <cr>'
endfunction

"-------------------------------------------------------------------------------------------------
function! misc#AstyleAllInFile(file)
    let astyle_cmd = '!astyle.exe -A1Lfpjk3S --mode=c --ascii -n '
    for line in readfile(a:file)
        echo line
        let cmd = misc#BuildCommand(astyle_cmd, line)
        silent execute cmd
        " exec 'normal :%s/\r//g <cr>'
    endfor
endfunction
" vim:set ft=vim et sw=4 sts=4:


