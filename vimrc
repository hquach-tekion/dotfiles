syntax on
filetype plugin indent on
set number
set termguicolors
set tabstop=2
set shiftwidth=2
set expandtab
set cursorline

call plug#begin('~/.vim/plugged')
Plug 'catppuccin/vim', { 'as': 'catppuccin' }
call plug#end()

silent! colorscheme catppuccin_mocha
