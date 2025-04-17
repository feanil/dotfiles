Git
===

Install git

Install github cli - https://github.com/cli/cli/blob/trunk/docs/install_linux.md

```
git clone git@github.com/feanil/dotfiles

ln -sf src/feanil/dotfiles/gitconfig.core ~/.gitconfig
```

Update as necessary for work and personal paths.

Setup ZSH and oh-my-zsh
=======================

Install zsh - https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH

fzf

Follow the instructions to install oh-my-zsh: https://ohmyz.sh/#install

Install powerlevel10k theme https://github.com/romkatv/powerlevel10k#oh-my-zsh

```
ln -sf ~/src/feanil/dotfiles/.p10k.zsh ~/.p10k.zsh
ln -sf ~/src/feanil/dotfiles/.zshrc ~/.zshrc
```


tmux
====

Install tmux

```
ln -sf ~/src/feanil/dotfiles/tmux.conf ~/.tmux.conf
```

Install HomeBrew
================

https://brew.sh/

```
brew install mcfly delta uv
```

Setup Python and Virtualenvwrapper
==================================

Install uv - https://github.com/astral-sh/uv

Setup python versions


mcfly
=====

- `ctrl-r` replacement - https://github.com/cantino/mcfly

Instructions - https://github.com/cantino/mcfly#installing-using-our-install-script

Release Page - https://github.com/cantino/mcfly/releases
- Get the musl version which will be fully statically linked.

delta
-----

- Diffing Tools for git and other diffing.

Release Page - https://github.com/dandavison/delta/releases
- Get the musl version which will be fully statically linked.

VIM
===

sudo add-apt-repository ppa:neovim-ppa/stable
Install NeoVim - unless you're on debian in which case the default vim is neovim.
mkvirtualenv neovim
pip install black isort neovim
ln -sf ~/src/feanil/dotfiles/config/nvim .config/nvim

Open Vim and run `:PlugInstall`


For getting the Yubikey working
===============================
Copy the .gnupg directory from a computere where its working.
Then install these relevant debian things: https://github.com/drduh/YubiKey-Guide#debian-and-ubuntu




Other tools to install
======================
A big list of options: https://github.com/ibraheemdev/modern-Unix


bat
---

- `cat` replacement - https://github.com/sharkdp/bat

Releases Page - https://github.com/sharkdp/bat/releases
- Get the musl version which will be fully statically linked.

exa
---

- `ls` replacement - https://github.com/ogham/exa

Instructions - https://github.com/ogham/exa#installation

jq
--

- Commandline JSON Parser

`sudo apt install jq`


