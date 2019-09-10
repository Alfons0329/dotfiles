set nocompatible " Use Vim defaults instead of 100% vi compatibility
set backspace=2 " m ore powerful backspacing
set shiftwidth=4
set smartindent
set tabstop=4       " 4 space for a tab
set expandtab
set mouse=a         "ok for mouse editing
set number
set cursorline
let g:go_version_warning=0

" -------------------------vundle starts here------------------- "
" statistical data wakatime
call vundle#begin()
Plugin 'wakatime/vim-wakatime'
Plugin 'Valloric/YouCompleteMe'
call vundle#end()
filetype plugin indent on
" -------------------------vundle starts here------------------- "
