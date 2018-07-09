" Copyright (c) 2018 Li Dengjie
"
" MIT License
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software"), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
"
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

let s:cpo_save = &cpo
set cpo&vim

"function! s:blank()
  ""execute 'win_gotoid('..')'
"endfunction

function! s:init_win(command)
  execute a:command
  setlocal buftype=nofile bufhidden=wipe nomodifiable nobuflisted noswapfile nonu nornu nocursorline nocursorcolumn winfixwidth winfixheight statusline=\
  setlocal colorcolumn=
  let winid = win_getid()

  " To hide scrollbars of win windows in GVim
  let diff = winheight(0) - line('$') - (has('gui_running') ? 2 : 0)
  if diff > 0
    setlocal modifiable
    call append(0, map(range(1, diff), '""'))
    normal! gg
    setlocal nomodifiable
  endif

  call s:hide_statusline()

  exe 'set modifiable | normal! gg dG | set no modifiable'

  execute winnr('#') . 'wincmd w'

  return winid
endfunction

function! s:get_color(group, attr)
  return synIDattr(synIDtrans(hlID(a:group)), a:attr)
endfunction
function! s:set_color(group, attr, color)
  let gui = has('gui_running') || has('termguicolors') && &termguicolors
  execute printf('hi %s %s%s=%s', a:group, gui ? 'gui' : 'cterm', a:attr, a:color)
endfunction
function! s:tranquilize()
  let bg = s:get_color('Normal', 'bg#')
  for grp in ['NonText', 'FoldColumn', 'ColorColumn', 'VertSplit',
            \ 'StatusLine', 'StatusLineNC', 'SignColumn']
    " -1 on Vim / '' on GVim
    if bg == -1 || empty(bg)
      call s:set_color(grp, 'fg', get(g:, 'absorb_bg', 'black'))
      call s:set_color(grp, 'bg', 'NONE')
    else
      call s:set_color(grp, 'fg', bg)
      call s:set_color(grp, 'bg', bg)
    endif
    call s:set_color(grp, '', 'NONE')
  endfor
endfunction

function! s:hide_statusline()
  setlocal statusline=\ 
endfunction

function! s:hide_linenr()
  if !get(g:, 'absorb_linenr', 0)
    setlocal nonu nornu colorcolumn=
  endif
endfunction

fu! s:closeinner()
    let cur_winid=win_getid()
    let i_winids_sorted = sort(t:absorb_wins.i_winids())
    for winidi in i_winids_sorted
        if winidi != cur_winid
            exe win_id2win(winidi).' wincmd c'
        endif
    endfor
endfu
fu! s:closeouter()
    let o_winids = t:absorb_wins.o_winids()
    for winidi in o_winids
        exe win_id2win(winidi).' wincmd c'
    endfor
    call absorb#reSizeWin()
endfu
fu! s:wintype(winid)
    if a:winid==0
        let target_winid=win_getid()
    elseif a:winid<1000
        let target_winid=win_getid(a:winid)
    else
        let target_winid=a:winid
    endif
    let wintype='inner'
    if index(t:absorb_wins.s_winids(),target_winid)>=0
        let wintype='surrounding'
    elseif index(t:absorb_wins.o_winids(),target_winid)>=0
        let wintype='outer'
    endif
    return wintype
endfu
fu! absorb#backtoinner()
    let cur_winnr=winnr()
    if s:wintype(0)!='inner'
        let i_winids_sorted = sort(t:absorb_wins.i_winids())
        for i_winid in i_winids_sorted
            exe win_id2win(i_winid).' wincmd w'
            if &filetype!='minibufexpl'
                break
            endif
        endfor
    endif
    return cur_winnr
endfu
fu! s:Wincmd(count,opr)
    let opr=a:opr[0]
    try
        let pasteValue=&paste
        set paste
        if index(['h','j','k','l'],opr)>=0
            call s:winSkip(max([a:count,1]),opr)
        elseif index(['v','s'],opr)>=0
            exe 'wincmd '.opr
        elseif opr == 'c'
            let target_winnr=a:count
            let cur_wintype=s:wintype(target_winnr)
            if cur_wintype=='surrounding'
                throw 'absorb: Can NOT close surrounding windows'
            elseif cur_wintype=='outer'
                let target_winnr=absorb#backtoinner()
                exe target_winnr.' wincmd '.opr
                call absorb#reSizeWin()
            else
                if t:absorb_wins.i_wins_count() >1
                    if target_winnr!=0
                        exe target_winnr.' wincmd '.opr
                    else
                        exe 'wincmd '.opr
                    endif
                else
                    throw 'absorb: Can NOT close the last inner window'
                endif
            endif
        elseif opr == 'o'
            call absorb#backtoinner()
            call s:closeinner()
        elseif opr == 'z'
            call absorb#backtoinner()
            "call s:closeinner()
            "call s:closeouter()
            call s:toggleMaxWin()
        elseif opr == 'r'
            call absorb#reSizeWin()
        else
            throw 'absorb: do NOT support ['.opr.']'
        endif
    finally
        let &paste=pasteValue
    endtry
endfu
fu! s:winSkip(count,opr)
    try
        let pasteValue=&paste
        set paste
        let t:skip_route={
                    \ t:lwin_winid : {'h':t:lwin_winid,'l':t:lwin_winid,'j':t:twin_winid,'k':t:bwin_winid,'to':'l'},
                    \ t:rwin_winid : {'h':t:rwin_winid,'l':t:rwin_winid,'j':t:twin_winid,'k':t:bwin_winid,'to':'h'},
                    \ t:twin_winid : {'h':t:rwin_winid,'l':t:lwin_winid,'j':t:twin_winid,'k':t:twin_winid,'to':'j'},
                    \ t:bwin_winid : {'h':t:rwin_winid,'l':t:lwin_winid,'j':t:bwin_winid,'k':t:bwin_winid,'to':'k'}
                    \}
        for ci in range(1,a:count)
            exe 'wincmd '.a:opr
            let last_winnr=winnr('#')
            let last_winid=win_getid(last_winnr)
            let cur_winid=win_getid()
            let s_winids=t:absorb_wins.s_winids()
            let s_index=index(s_winids,cur_winid)
            if s_index>=0

                let route_winnr=win_id2win(t:skip_route[cur_winid][a:opr])

                exe route_winnr.' wincmd w'
                exe 'wincmd ' . a:opr
                let midway_winid=win_getid()
                "如果跳不出去，说明是尽头，应返回
                if midway_winid==cur_winid
                    exe last_winnr.' wincmd w'
                    break
                "如果跳调到另一个边框，说明是outer往inner跳转时出错,应跳到inner
                elseif index(s_winids,midway_winid)>=0
                    let route_to=t:skip_route[midway_winid]['to']
                    exe 'wincmd ' . route_to
                endif
            endif
        endfor
        let final_winid=win_getid()
        if index(s_winids,final_winid)>=0
            let route_to=t:skip_route[final_winid]['to']
            exe 'wincmd ' . route_to
        elseif &filetype=='minibufexpl'
            exe 'wincmd j'
        endif
    finally
        let &paste=pasteValue
    endtry
endfu

function! s:get_winids(area) dict
    let winids=[]
    let s_united_scpos=self.s_united_scpos()
    for wi in range(1,winnr('$'))
        let cur_screenpos=win_screenpos(wi)
        if cur_screenpos[0]>s_united_scpos[0] && cur_screenpos[0]<s_united_scpos[2]&&cur_screenpos[1]>s_united_scpos[1]&&cur_screenpos[1]<s_united_scpos[3]
            if a:area=="inner" | call add(winids,win_getid(wi)) | endif
        elseif cur_screenpos[0]<s_united_scpos[0] || cur_screenpos[0]>s_united_scpos[2]||cur_screenpos[1]<s_united_scpos[1]||cur_screenpos[1]>s_united_scpos[3]
            if a:area=="outer" | call add(winids,win_getid(wi)) | endif
        else
            if a:area=="surrounding" | call add(winids,win_getid(wi)) | endif
        endif
    endfor
    return winids
endfunction
function! s:list_bufnames(winidlist) dict
    return map(deepcopy(self[a:winidlist]()),'bufname(winbufnr(v:val))')
endfunction
function! s:wins_count(winidlist) dict
	let wc=len(self[a:winidlist]())
	if a:winidlist=='i_winids' && index(t:absorb_wins.i_bufnames(),'-MiniBufExplorer-')>=0
		let wc -= 1
	endif
    return wc
endfunction
function! s:wins_united_screenpos(winidlist) dict
    let rows=[]
    let cols=[]
    if type(self[a:winidlist])==2
        let winidlist=self[a:winidlist]()
    else
        let winidlist=self[a:winidlist]
    endif
    for winid in winidlist
        call add(rows,win_screenpos(winid)[0])
        call add(cols,win_screenpos(winid)[1])
    endfor
    "[tpos,lpos,bpos,rpos]
    return [min(rows),min(cols),max(rows),max(cols)]
endfunction

function! s:initLayout()
    let absorb_5=[]

    let absorb_t_w=&columns
    let absorb_b_w=absorb_t_w
    let absorb_i_w=&columns * str2nr(get(g:,'absorb_width','80%')[:-2]) / 100
    let absorb_l_w=(&columns - absorb_i_w -2)/2
    let absorb_r_w=&columns - absorb_i_w -2 - absorb_l_w

    let absorb_i_h=&lines * str2nr(get(g:,'absorb_height','90%')[:-2]) / 100
    let absorb_l_h=absorb_i_h
    let absorb_r_h=absorb_i_h
    let absorb_t_h=(&lines - absorb_i_h -2)/2
    let absorb_b_h=&lines - absorb_i_h -2 - absorb_t_h

    call add(absorb_5,[absorb_t_h,absorb_t_w])
    call add(absorb_5,[absorb_l_h,absorb_l_w])
    call add(absorb_5,[absorb_i_h,absorb_i_w])
    call add(absorb_5,[absorb_r_h,absorb_r_w])
    call add(absorb_5,[absorb_b_h,absorb_b_w])

    let g:absorb_5=absorb_5
    return absorb_5
endfunction

function! s:calWinSize()
    let l:absorb_5 = s:initLayout()
    let absorb_7=[]
    let screenHeight=2+l:absorb_5[0][0]+l:absorb_5[1][0]+l:absorb_5[4][0]
    let screenWidth=l:absorb_5[0][1]

    if exists('t:NERDTreeBufName')
        let nerdtree_open = bufwinnr(t:NERDTreeBufName) != -1
    else
        let nerdtree_open = 0
    endif
    let tagbar_open = bufwinnr('__Tagbar__') != -1

    let absorb_ne_w=nerdtree_open ? g:NERDTreeWinSize : 0
    let absorb_ta_w=tagbar_open ? g:tagbar_width : 0
    let nt_lin_w=(nerdtree_open ? 1 : 0)+(tagbar_open ? 1 : 0)
    let n_line_w=nerdtree_open ? 1 : 0
    let t_line_w=tagbar_open? 1 : 0

    let nt_max_w=max([absorb_ne_w,absorb_ta_w])
    let absorb_l_w=max([1,nerdtree_open ? l:absorb_5[1][1]-nt_max_w-n_line_w : l:absorb_5[1][1]])
    let absorb_r_w=max([1,tagbar_open ? l:absorb_5[3][1]-nt_max_w-t_line_w : l:absorb_5[3][1]])
    let absorb_t_w=screenWidth-absorb_ne_w-absorb_ta_w-nt_lin_w
    let absorb_b_w=absorb_t_w
    let absorb_i_w=screenWidth-absorb_ne_w-absorb_ta_w-absorb_l_w-absorb_r_w-2-nt_lin_w

    let absorb_ne_w=nerdtree_open ? nt_max_w : 0
    let absorb_ta_w=tagbar_open ? nt_max_w : 0

    let s_winids=t:absorb_wins.s_winids_init
    
    if nerdtree_open 
        call add(absorb_7,{'winid':win_getid(bufwinnr(t:NERDTreeBufName)),'height':screenHeight,'width':absorb_ne_w})
    endif
    call add(absorb_7,{'winid':s_winids[2],'height':l:absorb_5[0][0],'width':absorb_t_w})
    call add(absorb_7,{'winid':s_winids[0],'height':l:absorb_5[1][0],'width':absorb_l_w})
    call add(absorb_7,{'winid':'iwin'     ,'height':l:absorb_5[2][0],'width':absorb_i_w})
    call add(absorb_7,{'winid':s_winids[1],'height':l:absorb_5[3][0],'width':absorb_r_w})
    call add(absorb_7,{'winid':s_winids[3],'height':l:absorb_5[4][0],'width':absorb_b_w})
    if tagbar_open 
        call add(absorb_7,{'winid':win_getid(bufwinnr('__Tagbar__')),'height':screenHeight,'width':absorb_ta_w})
    endif
    let g:absorb_7=absorb_7
    return absorb_7
endfunction

function! absorb#reSizeWin()
    "if exists("#absorb")
    "exe 'echo "'.localtime().'"'
    call absorb#backtoinner()

    let pasteValue=&paste
    set paste
    cclose
    let &paste=pasteValue

    let l:layout=s:calWinSize()

    for wininfo in l:layout
        let winid=wininfo.winid
        if winid != 'iwin'
            let winno=win_id2win(winid)
            let height=wininfo.height
            let width=wininfo.width
            execute 'vertical '.winno.' resize ' . width
            execute winno.' resize ' . height
        endif
    endfor
endfunction

"-- 最大化当前buffer窗口 --
function! s:toggleMaxWin()
    if exists("t:winMax")
        let l:winMax_tmp=t:winMax
        let l:curtab=tabpagenr()
        for tabno in range(1,tabpagenr('$'))
            execute 'normal! '.tabno.'gt'
            if exists("t:orig_tab") && t:orig_tab==l:winMax_tmp
                let l:winMax_orig_tabnr=tabpagenr()
            endif
            if exists("t:new_tab") && t:new_tab==l:winMax_tmp
                let l:winMax_new_tabnr=tabpagenr()
                let l:winMax_new_line=line('.')
                let l:winMax_new_col=col('.')
            endif
        endfor
        execute 'normal! '.l:curtab.'gt'

        if exists("l:winMax_orig_tabnr")
            if exists("l:winMax_new_tabnr")
                "是在新tab里操作时
                if l:winMax_orig_tabnr!=l:curtab
                    let winMax_cur_bufnr=winbufnr(0)
                    execute 'normal! '.l:winMax_orig_tabnr.'gt'
                    execute win_id2win(t:winMax_orig_winid) . 'wincmd w'
                    execute 'b'.winMax_cur_bufnr
                    execute printf('normal! %dG%d|', l:winMax_new_line, l:winMax_new_col)
                    execute 'normal! zz'
                endif
                execute 'tabclose '.l:winMax_new_tabnr
            endif
        endif

        unlet t:winMax
        if exists('t:orig_tab') | unlet t:orig_tab | endif
        if exists('t:new_tab') | unlet t:new_tab | endif

        "是在原来tab里操作时,关闭前一个最大化窗口后,自动最大化当前buffer
        if l:winMax_orig_tabnr==l:curtab
            call s:maxWin()
        endif
    else
        call s:maxWin()
    endif
endfunction
function! s:maxWin()
    "只有一个窗口时,不操作
    if t:absorb_wins.i_wins_count()>1 || t:absorb_wins.o_wins_count()>0
        let l:winMax_id=localtime()
        let l:winMax_orig_winid_tmp=win_getid()

        let t:winMax=l:winMax_id
        let t:orig_tab=l:winMax_id
        let t:winMax_orig_winid=l:winMax_orig_winid_tmp
        tab split
        call s:absorb_on()
        let t:winMax=l:winMax_id
        let t:new_tab=l:winMax_id
        let t:winMax_orig_winid=l:winMax_orig_winid_tmp
        execute 'normal! zz'
    endif
endfunction

fu! s:quitall()
    let cur_wintype=s:wintype(0)
    if cur_wintype=='surrounding'
        throw 'absorb: Can NOT close surrounding windows'
    elseif cur_wintype=='outer'
        return 'Wincmd c'
    else
        if t:absorb_wins.i_wins_count()==1
            return 'qall'
        else
            return 'q'
        endif
    endif
endfu
fu! s:wquitall()
    let cur_wintype=s:wintype(0)
    if cur_wintype=='surrounding'
        throw 'absorb: Can NOT close surrounding windows'
    elseif cur_wintype=='outer'
        return 'Wincmd c'
    else
        if t:absorb_wins.i_wins_count()==1
            return 'wqall'
        else
            return 'wq'
        endif
    endif
endfu

function! s:turnOffTmuxStatus()
    if exists('$TMUX')
        silent !tmux set status off > /dev/null
        silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
    endif
endfunction
function! s:turnOnTmuxStatus()
    if exists('$TMUX')
        silent !tmux set status on > /dev/null
        silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
    endif
endfunction
fu! s:moveBuffer()
    if exists("t:absorb_wins")
        try
            let pasteValue=&paste
            set paste
            let orig_winid=win_getid()
            let orig_bufnr=winbufnr(0)
            let wintype=s:wintype(0)
            if wintype=='surrounding'
                let s_winids_init=t:absorb_wins.s_winids_init
                if index(s_winids_init,orig_winid)<0
                    call absorb#backtoinner()
                    exe 'wincmd s'
                    exe 'wincmd j'
                    exe 'b '.orig_bufnr
                    exe win_id2win(orig_winid).' wincmd c'
                endif
            endif
        finally
            let &paste=pasteValue
        endtry
    endif
endfu
fu! s:showWinInfo()
    exe 'echo "==> '.s:wintype(0).' '.win_getid()." ".winnr()." ".winbufnr("")." ".bufname("").'"'
endfu
fu! s:hide_cursorline()
    if &filetype=='minibufexpl'
        set nocursorline
    endif
    if exists("t:absorb_wins")
        let wintype=s:wintype(0)
        if wintype!='inner' || &filetype=='minibufexpl'
            set nocursorline
        endif
    endif
endfu
fu! s:nerdtreeToggle(opr)
    if a:opr=='toggle'
        NERDTreeToggle
    elseif a:opr=='open'
        NERDTree
    elseif a:opr=='close'
        NERDTreeClose
    endif
    call absorb#reSizeWin()
endfu
fu! s:tagbarToggle(opr)
    if a:opr=='toggle'
        TagbarToggle
    elseif a:opr=='open'
        TagbarOpen
    elseif a:opr=='close'
        TagbarClose
    endif
    call absorb#reSizeWin()
endfu

function! s:absorb_on()

    " vim-gitgutter
    let t:absorb_disabled_gitgutter = get(g:, 'gitgutter_enabled', 0)
    if t:absorb_disabled_gitgutter
        silent! GitGutterDisable
    endif

    " vim-signify
    let t:absorb_disabled_signify = exists('b:sy') && b:sy.active
    if t:absorb_disabled_signify
        SignifyToggle
    endif

    " vim-airline
    let t:absorb_disabled_airline = exists('#airline')
    if t:absorb_disabled_airline
        AirlineToggle
    endif

    " vim-powerline
    let t:absorb_disabled_powerline = exists('#PowerlineMain')
    if t:absorb_disabled_powerline
        augroup PowerlineMain
            autocmd!
        augroup END
        augroup! PowerlineMain
    endif

    " lightline.vim
    let t:absorb_disabled_lightline = exists('#lightline')
    if t:absorb_disabled_lightline
        silent! call lightline#disable()
    endif

    if exists("#MiniBufExpl")
		let g:miniBufExplStatusLineText=" "
        MBEClose
    endif


    call s:turnOffTmuxStatus()

    call s:hide_linenr()
    " Global options
    let &winheight = max([&winminheight, 1])
    set winminheight=1
    set winheight=1
    set winminwidth=1 winwidth=1
    set laststatus=0
    set showtabline=0
    set noruler
    set fillchars+=vert:\ 
    set fillchars+=stl:\ 
    set fillchars+=stlnc:\ 
    set sidescroll=1
    set sidescrolloff=0

    " Hide left-hand scrollbars
    if has('gui_running')
        set guioptions-=l
        set guioptions-=L
    endif

    let t:lwin_winid = s:init_win('vertical topleft new')
    let t:rwin_winid = s:init_win('vertical botright new')
    let t:twin_winid = s:init_win('topleft new')
    let t:bwin_winid = s:init_win('botright new')
    let t:absorb_wins = {
                \ 's_winids_init' : [t:lwin_winid,t:rwin_winid,t:twin_winid,t:bwin_winid],
                \ 's_winids' : function("s:get_winids",['surrounding']),
                \ 's_bufnames' : function('s:list_bufnames',['s_winids']),
                \ 's_wins_count' : function("s:wins_count",["s_winids"]),
                \ 's_united_scpos' : function("s:wins_united_screenpos",['s_winids_init']),
                \ 'i_winids' : function("s:get_winids",['inner']),
                \ 'i_bufnames' : function('s:list_bufnames',['i_winids']),
                \ 'i_wins_count' : function("s:wins_count",["i_winids"]),
                \ 'o_winids' : function("s:get_winids",['outer']),
                \ 'o_bufnames' : function('s:list_bufnames',['o_winids']),
                \ 'o_wins_count' : function("s:wins_count",["o_winids"])
                \}

    call absorb#reSizeWin()

    call s:tranquilize()
    call s:hide_statusline()

    augroup absorb
        autocmd!
        autocmd VimResized  *        call absorb#reSizeWin()
        autocmd ColorScheme *        call s:tranquilize()
        autocmd BufWinEnter *        call s:hide_linenr() | call s:hide_statusline() 
        autocmd WinEnter,WinLeave *  call s:hide_statusline()| call s:hide_cursorline()
        if has('nvim')
            autocmd TermClose * call feedkeys("\<plug>(absorb-resize)")
        endif
        autocmd QuitPre * call s:turnOnTmuxStatus()
        autocmd BufEnter *        call  s:moveBuffer()
        "autocmd BufEnter *        call  s:showWinInfo()
    augroup END

    let oplist=['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
                \'+','-','.',':','<','=','>',']','^','_','}',
                \'<Down>','<Up>','<Left>','<Right>']
                "\'#','$','%','^','&','*','(',')','_','-','+','=',
                "\'{','[','}',']','|','\',':',';','"','<',',','>','.','?','/'
    for opi in oplist
        exe 'map <expr> <silent> <c-w>'.opi.' ":<c-u>".v:count." wincmd '.opi.'<cr>"'
    endfor
    cabbrev  wincmd Wincmd
    command! -nargs=1 -count=0 -bar Wincmd call <sid>Wincmd(<count>,<q-args>)

    nnoremap <silent> <plug>(absorb-resize) :<c-u>call absorb#reSizeWin()<cr>

    cabbrev <expr> q <SID>quitall()
    cabbrev <expr> wq <SID>wquitall()
    cabbrev cclose cclose <bar> call absorb#reSizeWin()
    cabbrev bn call absorb#backtoinner() <bar> bn
    cabbrev bp call absorb#backtoinner() <bar> bp
    cabbrev b call absorb#backtoinner() <bar> b
    cabbrev bd call absorb#backtoinner() <bar> bd
    cabbrev bdel call absorb#backtoinner() <bar> bdel

    cabbrev MBEToggle call absorb#backtoinner() <bar> MBEToggle
    cabbrev MBEClose call absorb#backtoinner() <bar> MBEClose
    cabbrev MBEOpen call absorb#backtoinner() <bar> MBEOpen
    cabbrev MBEbd call absorb#backtoinner() <bar> MBEbd
    cabbrev MBEbn call absorb#backtoinner() <bar> MBEbn
    cabbrev MBEbp call absorb#backtoinner() <bar> MBEbp
    cabbrev NERDTreeToggle call <SID>nerdtreeToggle('toggle')
    cabbrev NERDTree call <SID>nerdtreeToggle('toggle')
    cabbrev NERDTreeClose call <SID>nerdtreeToggle('toggle')
    cabbrev TagbarToggle call <SID>tagbarToggle('toggle')
    cabbrev TagbarOpen call <SID>tagbarToggle('open')
    cabbrev TagbarClose call <SID>tagbarToggle('close')

    if exists('g:absorb_callbacks[0]')
        call g:absorb_callbacks[0]()
    endif
    if exists('#User#AbsorbAfterEnter')
        doautocmd User AbsorbAfterEnter
    endif
endfunction

function! absorb#execute()
    call s:absorb_on()
    "exe "highlight VertSplit ctermbg='red' | highlight StatusLine ctermbg='black' | highlight StatusLineNC ctermbg='white'"
    let l:hasFile=len(bufname("%"))
    if !l:hasFile
        exe "NERDTree"
    endif
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
