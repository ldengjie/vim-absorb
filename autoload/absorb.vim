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
fu! s:backtoinner()
    let cur_winnr=winnr()
    if s:wintype(0)!='inner'
        let i_winids_sorted = sort(t:absorb_wins.i_winids())
        exe win_id2win(i_winids_sorted[0]).' wincmd w'
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
                let target_winnr=s:backtoinner()
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
            call s:backtoinner()
            call s:closeinner()
        elseif opr == 'z'
            call s:backtoinner()
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
        let skip_route={
                    \ 'lwin' : {'h':'lwin','l':'lwin','j':'twin','k':'bwin','to':'l'},
                    \ 'rwin' : {'h':'rwin','l':'rwin','j':'twin','k':'bwin','to':'h'},
                    \ 'twin' : {'h':'rwin','l':'lwin','j':'twin','k':'twin','to':'j'},
                    \ 'bwin' : {'h':'rwin','l':'lwin','j':'bwin','k':'bwin','to':'k'}
                    \}
        let g:tes=[]
        call add(g:tes,a:count)
        call add(g:tes,a:opr)
        for ci in range(1,a:count)
            exe 'wincmd '.a:opr
            let last_winid=win_getid(winnr('#'))
            let cur_winid=win_getid()
            let s_winids=t:absorb_wins.s_winids()
            let s_index=index(s_winids,cur_winid)
            if s_index>=0

                let s_bufnames=t:absorb_wins.s_bufnames()
                let s_bufname2winid={}
                for s_i in range(len(s_bufnames))
                    let s_bufname2winid[s_bufnames[s_i]]=s_winids[s_i]
                endfor

                let cur_name=s_bufnames[s_index]
                let route_bufname=skip_route[cur_name][a:opr]
                let route_winnr=win_id2win(s_bufname2winid[route_bufname])

                exe route_winnr.' wincmd w'
                exe 'wincmd ' . a:opr
                let final_winid=win_getid()
                "如果跳不出去，说明是尽头，应返回
                if final_winid==cur_winid
                    exe win_id2win(last_winid).' wincmd w'
                "如果跳调到另一个边框，说明是outer往inner跳转时出错,应跳到inner
                elseif index(s_winids,final_winid)>=0
                    let cur_name=s_bufnames[index(s_winids,final_winid)]
                    let route_to=skip_route[cur_name]['to']
                    exe 'wincmd ' . route_to
                endif
                call add(g:tes,route_winnr.' wincmd w')
                call add(g:tes,'wincmd ' . a:opr)
            endif
        endfor
    finally
        let &paste=pasteValue
    endtry
endfu

function! s:get_winids(area) dict
    let winids=[]
    if a:area=="inner"
        let s_united_scpos=self.s_united_scpos()
        for wi in range(1,winnr('$'))
            let cur_screenpos=win_screenpos(wi)
            if cur_screenpos[0]>s_united_scpos[0] && cur_screenpos[0]<s_united_scpos[2]&&cur_screenpos[1]>s_united_scpos[1]&&cur_screenpos[1]<s_united_scpos[3]
                call add(winids,win_getid(wi))
            endif
        endfor
    elseif a:area=="outer"
        let s_united_scpos=self.s_united_scpos()
        for wi in range(1,winnr('$'))
            let cur_screenpos=win_screenpos(wi)
            if cur_screenpos[0]<s_united_scpos[0] || cur_screenpos[0]>s_united_scpos[2]||cur_screenpos[1]<s_united_scpos[1]||cur_screenpos[1]>s_united_scpos[3]
                call add(winids,win_getid(wi))
            endif
        endfor
    elseif a:area=="surrounding"
        let winids=deepcopy(t:absorb_wins.s_winids_init)
    endif
    return winids
endfunction
function! s:list_bufnames(winidlist) dict
    if a:winidlist=="s_winids"
        let bufnames=self.s_bufnames_init
    else
        let winids=self[a:winidlist]()
        let bufnames=map(deepcopy(winids),'bufname(winbufnr(v:val))')
    endif
    return bufnames
endfunction
function! s:wins_count(winidlist) dict
    return len(self[a:winidlist]())
endfunction
function! s:wins_united_screenpos(winidlist) dict
    let rows=[]
    let cols=[]
    for winid in self[a:winidlist]()
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

    if nerdtree_open | call add(absorb_7,[screenHeight,absorb_ne_w]) | endif
    call add(absorb_7,[l:absorb_5[0][0],absorb_t_w])
    call add(absorb_7,[l:absorb_5[1][0],absorb_l_w])
    call add(absorb_7,[l:absorb_5[2][0],absorb_i_w])
    call add(absorb_7,[l:absorb_5[3][0],absorb_r_w])
    call add(absorb_7,[l:absorb_5[4][0],absorb_b_w])
    if tagbar_open | call add(absorb_7,[screenHeight,absorb_ta_w]) | endif
    let g:absorb_7=absorb_7
    return absorb_7
endfunction

function! absorb#reSizeWin()
    "if exists("#absorb")
    "exe 'echo "'.localtime().'"'
    call s:backtoinner()
    let l:layout=s:calWinSize()
    for winno in range(1,len(l:layout))
        execute 'vertical '.winno.' resize ' . l:layout[winno-1][1]
        execute winno.' resize ' . l:layout[winno-1][0]
    endfor
    "BUG:需要执行两遍,否则1)从absorb_6_t(只打开tagbar)返回absorb_5时，窗口并没有正确改变大小
    for winno in range(1,len(l:layout))
        execute 'vertical '.winno.' resize ' . l:layout[winno-1][1]
        execute winno.' resize ' . l:layout[winno-1][0]
    endfor
    "endif
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
                    execute 'normal! '.l:winMax_orig_tabnr.'gt'
                    execute win_id2win(t:winMax_orig_winid) . 'wincmd w'
                    execute 'b'.t:winMax_orig_bufnr
                    execute printf('normal! %dG%d|', l:winMax_new_line, l:winMax_new_col)
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
    if t:absorb_wins.i_wins_count()>1
        let l:winMax_id=localtime()
        let l:winMax_orig_winid_tmp=win_getid()
        let l:winMax_orig_bufnr_tmp=winbufnr(0)

        let t:winMax=l:winMax_id
        let t:orig_tab=l:winMax_id
        let t:winMax_orig_winid=l:winMax_orig_winid_tmp
        let t:winMax_orig_bufnr=l:winMax_orig_bufnr_tmp
        tab split
        call s:absorb_on()
        let t:winMax=l:winMax_id
        let t:new_tab=l:winMax_id
        let t:winMax_orig_winid=l:winMax_orig_winid_tmp
        let t:winMax_orig_bufnr=l:winMax_orig_bufnr_tmp
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
            return 'Wincmd c'
        endif
    endif
endfu

function! s:turnOffTmuxStatus()
    if exists('$TMUX')
        silent !tmux set status off
        silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
    endif
endfunction
function! s:turnOnTmuxStatus()
    if exists('$TMUX')
        silent !tmux set status on 
        silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
    endif
endfunction

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

    "t:
    "{flag:v,height:,width:,pads:[v1,v2]}
    "v1: {flag:h,height:46,width:180,pads:[v1h1,v1h2,v1h3]}
    "v1h1: {flag:w,height:46,width:20}
    "v1h2: {flag:v,height:,width:,pads:[v1h2v1,v1h2v2,v1h2v3]}
    "v1h2v1: {flag:w,height:1,width:139}
    "v1h2v2: {flag:h,height:,width:,pads:[v1h2v2h1,v1h2v2h2,v1h2v2h2]}
    "v1h2v2h1: {flag:w,height:30,width:46}
    "v1h2v2h2: {flag:w,height:30,width:46}
    "v1h2v2h3: {flag:w,height:30,width:46}
    "v1h2v3: {flag:w,height:1,width:139}
    "v1h3: {flag:w,height:46,width:20}
    "v2: {flag:w,height:4,width:181}

    "fu! s:explorsPad(winid)
    "endfu

    "function! Tree(lst, ret)
    "if empty(a:lst)
    "return a:ret
    "endif
    "let _ = a:ret + get(a:lst, 0)
    "return Tree(a:lst[1:-1], _)
    "endfunction

    let t:absorb_wins = {
                \ 's_winids_init' : [s:init_win('vertical topleft new'),s:init_win('vertical botright new'),s:init_win('topleft new'),s:init_win('botright new')],
                \ 's_bufnames_init' : ['lwin','rwin','twin','bwin'],
                \ 's_winids' : function("s:get_winids",['surrounding']),
                \ 's_bufnames' : function('s:list_bufnames',['s_winids']),
                \ 's_wins_count' : function("s:wins_count",["s_winids"]),
                \ 's_united_scpos' : function("s:wins_united_screenpos",['s_winids']),
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
        autocmd WinEnter,WinLeave *  call s:hide_statusline()
        if has('nvim')
            autocmd TermClose * call feedkeys("\<plug>(absorb-resize)")
        endif
        autocmd QuitPre * call s:turnOnTmuxStatus()
    augroup END

    let oplist=['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
                \'+','-','.',':','<','=','>',']','^','_','}',
                \'<Down>','<Up>','<Left>','<Right>']
                "\'#','$','%','^','&','*','(',')','_','-','+','=',
                "\'{','[','}',']','|','\',':',';','"','<',',','>','.','?','/'
    for opi in oplist
        exe 'map <silent> <c-w>'.opi.' : wincmd '.opi.'<cr>'
    endfor
    "for opi in oplist
    "for count in range(9)
    "exe 'map <c-w> '.count.' '.opi.' :<c-\><c-n>'.count.' wincmd '.opi.'<cr>'
    "endfor
    "endfor
    "for opi in oplist
    "for count in range(9)
    "exe 'map '.count.'<c-w> '.opi.' :<c-\><c-n>'.count.' wincmd '.opi.'<cr>'
    "endfor
    "endfor
    cabbrev  wincmd Wincmd
    command! -nargs=1 -count=0 -bar Wincmd call <sid>Wincmd(<count>,<q-args>)

    nnoremap <silent> <plug>(absorb-resize) :<c-u>call absorb#reSizeWin()<cr>

    cabbrev <expr> q <SID>quitall()

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
