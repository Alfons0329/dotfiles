"syntax and line...etc
set number
syntax on

" Configuration file for vim
set modelines=0		" CVE-2007-2438

" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements

"text editing
set nocompatible	" Use Vim defaults instead of 100% vi compatibility
set backspace=2		" more powerful backspacing
set shiftwidth=4
set smartindent
set tabstop=4       " 4 space for a tab
set expandtab
set mouse=a         "ok for mouse editing

" Don't write backup file if vim is being called by "crontab -e"
au BufWrite /private/tmp/crontab.* set nowritebackup nobackup
" Don't write backup file if vim is being called by "chpass"
au BufWrite /private/etc/pw.* set nowritebackup nobackup

let skip_defaults_vim=1


"my keyremap here for the old style

"part one the shift-selection

nmap <S-Up> v<Up>
nmap <S-Down> v<Down>
nmap <S-Left> v<Left>
nmap <S-Right> v<Right>
vmap <S-Up> <Up>
vmap <S-Down> <Down>
vmap <S-Left> <Left>
vmap <S-Right> <Right>
imap <S-Up> <Esc>v<Up>
imap <S-Down> <Esc>v<Down>
imap <S-Left> <Esc>v<Left>
imap <S-Right> <Esc>v<Right>

:map <C-a> GVgg
:map <C-n> :enew
:map <C-o> :e . <Enter>
:map <C-s> :w <Enter>
:map <C-c> <Esc>y
:map <C-v> <Esc>p
:map <C-x> <Esc>d
:map <C-z> <Esc>u
:map <C-h> :%s/
:map <C-W> :q! <Enter>
:map <C-f> /
:map <F3> n

"line editing
:map <C-S-D> yyp "duplicate whole line
:map <C-S-K> dd "delete while line
