" ~/.vimrc - configuration for PLAIN VIM ONLY.
"
" Neovim does not read this file. Its config lives in ~/.config/nvim/init.lua
" and shares nothing with this one.
"
" That separation is deliberate. The previous setup had Neovim source a
" VimScript framework through ~/.vimrc, which dragged in a second statusline
" plugin and a second colorscheme; they fought over &statusline and the theme
" visibly changed after every :w. Two independent files cannot collide.
"
" Keep this small. It is the editor you get for a git commit message, a quick
" edit in a root shell, or a box where Neovim isn't installed. Real work
" happens in nvim.

set nocompatible

syntax on
filetype plugin indent on

" Indentation: 4 spaces, no hard tabs.
set expandtab
set shiftwidth=4
set tabstop=4
set softtabstop=4
set autoindent
set smartindent

" Display
set number
set cursorline
set ruler
set showcmd
set laststatus=2
set scrolloff=4
set wildmenu
set wildmode=longest:full,full

" Search
set incsearch
set hlsearch
set ignorecase
set smartcase
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

" Behaviour
set backspace=indent,eol,start
set mouse=a
set encoding=utf-8
set history=1000
set hidden
set noswapfile
set nobackup

" Reopen a file at the line you left it on.
autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   execute "normal! g`\"" |
    \ endif
