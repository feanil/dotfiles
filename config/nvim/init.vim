" Disable python 2 support
let g:loaded_python_provider = 0

" Set tsserver binary to a shell script so we can pass extra options
let g:ycm_tsserver_binary_path = '/home/feanil/.local/bin/tsserverproxy.sh'

" Point to neovim virtualenv.
let g:python3_host_prog = '/home/feanil/.virtualenvs/neovim/bin/python'
let g:vim_isort_python_version = 'python3'

let g:black_virtualenv = '/home/feanil/.virtualenvs/neovim'
"let g:black_linelength = 99
let g:black_quiet = 1

call plug#begin('~/.local/share/nvim/plugged')

" Code Editing
Plug 'editorconfig/editorconfig-vim'
Plug 'elmcast/elm-vim'
Plug 'rust-lang/rust.vim'
Plug 'cespare/vim-toml'
Plug 'psf/black'
Plug 'fisadev/vim-isort'
" Plug 'ycm-core/YouCompleteMe'
Plug 'hashivim/vim-terraform'
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeFind' }
Plug 'junegunn/fzf'
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

" personal code should use black but forks should not.
autocmd BufWritePre ~/src/personal/*.py execute ':Black'
autocmd BufWritePre ~/src/personal/*.py execute ':Isort'

" Open edX things are not using these yet but we should for hacking.
autocmd BufWritePre ~/work/src/hacking/*.py execute ':Black'
autocmd BufWritePre ~/work/src/hacking/*.py execute ':Isort'

" Open edX things that have black and isort enabled
" terraform-github
autocmd BufWritePre ~/work/src/openedx/terraform-github/*.py execute ':Black'
autocmd BufWritePre ~/work/src/openedx/terraform-github/*.py execute ':Isort'

" docs.openedx.org
autocmd BufWritePre ~/work/src/openedx/docs.openedx.org/*.py execute ':Black'
autocmd BufWritePre ~/work/src/openedx/docs.openedx.org/*.py execute ':Isort'

" my work related repos
autocmd BufWritePre ~/work/src/feanil/*.py execute ':Black'
autocmd BufWritePre ~/work/src/feanil/*.py execute ':Isort'

set number
set ruler

" Reference https://stackoverflow.com/questions/30691466/what-is-difference-between-vims-clipboard-unnamed-and-unnamedplus-settings
set clipboard^=unnamed,unnamedplus

nmap <C-n> :NERDTreeFind<CR>
nmap <C-l> :FZF<CR>
