if exists("g:loaded_libvim_path") || &cp || v:version < 700
    finish
endif
let g:loaded_libvim_path = 1

"----------------------------------------------------------------
" ConvertToCygPath
function! path#ConvertToCygPath(path)
    let l:path = a:path
    let l:path = substitute(l:path, 'C:', '/cygdrive/c', "g") 
    let l:path = substitute(l:path, 'D:', '/cygdrive/d', "g") 
    let l:path = substitute(l:path, 'E:', '/cygdrive/e', "g") 
    let l:path = substitute(l:path, '\', '/', "g") 
    return l:path
endfunction

"----------------------------------------------------------------
" ConvertToWinPath
function! path#ConvertToWinPath(path)
    let l:path = a:path
    let l:path = substitute(l:path, '/cygdrive/c', 'C:', "g") 
    let l:path = substitute(l:path, '/cygdrive/d', 'D:', "g") 
    let l:path = substitute(l:path, '/cygdrive/e', 'E:', "g") 
    return l:path
endfunction

"----------------------------------------------------------------
" rsync
function! path#Rsync(localPath, user, remoteAddr, remotePort, remotePath, proxyAddr, identityFile)
    if(!ingo#fs#path#Exists(a:localPath))
        echohl WarningMsg | echo a:localPath . 'not exists' | echohl None
        return -1
    endif
    if(misc#CheckParamsNotEmpty(a:user, a:remoteAddr, a:remotePath))
        echohl WarningMsg | echo 'param is empty' | echohl None
        return -1
    endif

    let cmd = "rsync -avzuh "
    if(filereadable(a:identityFile))
        let identity = path#ConvertToCygPath(a:identityFile)
        let fmt = " -e 'ssh -i %s' "
        if(!empty(a:proxyAddr))
            let fmt = " -e 'ssh -i %s -o \"ProxyCommand=nc -X connect -x %s \%h \%p\" '"
        endif
        let cmd = cmd . printf(fmt, identity, proxyAddr)
    endif

    let cmd = cmd . printf("%s -p %d %s@%s:%s", path#ConvertToCygPath(a:localPath), a:remotePort, a:user, a:remoteAddr, a:remotePath)
    call misc#RunCommand(cmd)
    return 0
endfunction

" vim:set ft=vim et sw=4 sts=4:
