" Disable python 2 support
let g:loaded_python_provider = 0

" Set tsserver binary to a shell script so we can pass extra options
let g:ycm_tsserver_binary_path = '/home/feanil/.local/bin/tsserverproxy.sh'

" Point to neovim virtualenv.
let g:python3_host_prog = '/home/feanil/.virtualenvs/neovim/bin/python'

let g:vim_isort_python_version = 'python3'

call plug#begin('~/.local/share/nvim/plugged')

Plug 'editorconfig/editorconfig-vim'
Plug 'elmcast/elm-vim'
Plug 'rust-lang/rust.vim'
Plug 'cespare/vim-toml'
Plug 'psf/black', { 'branch': 'stable' }
Plug 'fisadev/vim-isort'
Plug 'ycm-core/YouCompleteMe'
" Make sure you use single quotes

" Shorthand notation; fetches https://github.com/junegunn/vim-easy-alignPlug 'junegunn/vim-easy-align'

" Any valid git URL is allowed
" Plug 'https://github.com/junegunn/vim-github-dashboard.git'

" Multiple Plug commands can be written in a single line using | separators
" Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'

" On-demand loading
" Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
" Plug 'tpope/vim-fireplace', { 'for': 'clojure' }

" Using a non-master branch
" Plug 'rdnetto/YCM-Generator', { 'branch': 'stable' }

" Using a tagged release; wildcard allowed (requires git 1.9.2 or above)
" Plug 'fatih/vim-go', { 'tag': '*' }

" Plugin options
" Plug 'nsf/gocode', { 'tag': 'v.20150303', 'rtp': 'vim' }

" Plugin outside ~/.vim/plugged with post-update hook
" Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }

" Unmanaged plugin (manually installed and updated)
" Plug '~/my-prototype-plugin'

" Initialize plugin system
call plug#end()

autocmd BufWritePre *.py execute ':Black'
autocmd BufWritePre *.py execute ':Isort'

set number
