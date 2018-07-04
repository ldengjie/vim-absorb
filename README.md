absorb.vim 
=========================================================

absorption mode writing in Vim.


Installation
------------

Use your favorite plugin manager.

- vim-plug
  1. Add `Plug 'ldengjie/vim-absorb'` to .vimrc
  2. Run `:PlugInstall`

Usage
-----

<C-W> supported: h j k l v s o z c

Configuration
-------------

```
let g:absorb_width  = '80%'  
let g:absorb_height = '90%'  
let g:absorb_linenr = 0
nmap <silent> cq :cclose<CR>:call absorb#reSizeWin()<CR>  
nnoremap  <Leader>n :NERDTreeToggle <bar>call absorb#reSizeWin()<CR>  
nnoremap  <Leader>t :call tagbar#ToggleWindow()<CR>:call absorb#reSizeWin()<CR>  
autocmd VimEnter * call absorb#execute()  
nmap <silent> ab :call absorb#execute()<CR>  
```

Inspiration
-----------

- [goyo](https://github.com/junegunn/goyo.vim)

License
-------

MIT

